// Normal-mode capture backend: complete PENDING-window scan -> qualification ->
// selected RAW record. Request metadata/noise must be frozen at pulse onset.
// Existing captures can submit scans during reset drainage; only NEW capture
// admissions are blocked. Upstream retains unsubmitted capture descriptions.
module calibrator_capture_pipeline #(
 parameter integer PRE_SAMPLES=250,DETECTOR_LATENCY=0,FIFO_ADDR_W=12,PHYSICAL_MASKS_IN_TEMPLATE=0,ONLINE_STATS=0,ENABLE_FINE=0
)(
 input wire fine_command_valid,fine_command_pop,input wire [63:0] fine_command_token,
 output wire fine_command_ready,fine_response_valid,fine_response_ok,fine_available_rf,
 output wire [1151:0] fine_response_data,
 input wire [191:0] online_tops,input wire online_valid,input wire [511:0] online_stats,input wire [191:0] online_peaks,input wire [7:0] online_error,
 input wire aux_request_valid,aux_qualified,aux_meta_pop,
 input wire [31:0] aux_request_count,input wire [63:0] aux_request_tx_token,aux_sample_gsc,aux_meta_pop_key,
 input wire [127:0] aux_context,input wire [1023:0] aux_template_header,
 output wire aux_request_ready,aux_request_accepted,aux_request_rejected,aux_meta_valid,aux_meta_pop_ok,aux_busy,
 output wire [767:0] aux_meta_data,
 output wire pdw_valid,output wire [255:0] pdw_key,output wire [1023:0] pdw_header,output wire [511:0] pdw_stats,output wire [191:0] pdw_peaks,
 output wire [15:0] replay_leased,
 input wire clk_rf,clk_mem,rst_n,arm_enable,reset_request,producers_idle,replay_quiescent,
 input wire sample_valid,input wire [63:0] sample_seq,input wire [255:0] group_data,
 input wire primary_trigger,input wire [63:0] primary_onset,primary_pulse_id,
 input wire [15:0] eop_valid,input wire [1023:0] eop_stop,eop_generation,
 input wire request_valid,output wire request_ready,input wire want_replay,
 input wire [255:0] request_key,frozen_noise,
 input wire [1023:0] config_data,input wire [3071:0] headers,
 input wire [5:0] bank_ids,bad_channels,input wire [191:0] bank_generations,
 output wire [7:0] statistics_error,
 output wire disposition_valid,descriptor_accepted,disposition_rejected,
 input wire ack_replay,input wire [3:0] ack_replay_bank,
 input wire [63:0] ack_replay_epoch,ack_replay_generation,
 input wire [15:0] replay_enable,input wire [223:0] replay_address,
 output wire [1023:0] replay_data,output wire [15:0] replay_valid,
 output wire completion_valid,completion_error,
 output wire [63:0] completion_epoch,completion_generation,
 output wire [1:0] completion_group,completion_bank,
 output wire [31:0] record_errors,rejected_returns,dropped_triggers,
 output wire [15:0] write_enable,armed,pending,frozen,truncated,qualified,
 output wire [1023:0] start_seq,generation,pulse_id,output wire [239:0] sample_count,
 output wire [63:0] owner_epoch,
 output wire quiesce,idle_rf,primary_admitted,block_new_work,reset_busy,reset_done,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,
 output wire m_axis_tlast,m_axis_tvalid,input wire m_axis_tready,
 output wire [FIFO_ADDR_W:0] fifo_occupancy
);
 (* ASYNC_REG="TRUE" *) reg [1:0] rf_up;
 always @(posedge clk_rf or negedge rst_n)if(!rst_n)rf_up<=0;else rf_up<={rf_up[0],1'b1};
 wire rst=!rf_up[1];wire fine_idle_rf;
 wire aux_trigger,aux_admitted,aux_drain_busy;wire [63:0] aux_onset,aux_pulse_id;
 wire [15:0] main_stats_valid,main_publish;wire [1023:0] main_stats_generation;
 wire [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending,pending_stats_enable,pending_stats_valid;
 wire [1023:0] stats_generation,pending_stats_data;wire [223:0] pending_stats_address;
 wire [3:0] desc_valid,desc_ready,stale_descriptor;wire [4095:0] desc_headers;wire [7:0] desc_banks;
 wire [255:0] source_expected_epoch,source_expected_generation;
 wire owner_reset_request,bridge_idle,scan_ready,bridge_ready,reader_busy;
 wire measurement_valid,measurement_ready;wire [255:0] measurement_key;wire [511:0] measurement_data;
 reg noise_pending;reg [255:0] noise_key,noise_data;wire noise_ready;
 wire event_valid,event_ready,event_published,event_rejected;wire [511:0] event_stats;wire [191:0] event_peaks,measurement_peaks;
 assign pdw_valid=descriptor_accepted;assign pdw_key=event_key;assign pdw_header=event_header;assign pdw_stats=event_stats;assign pdw_peaks=event_peaks;
 wire [255:0] event_key;wire [3:0] event_bank;wire [1023:0] event_header;wire [63:0] event_generation,event_epoch;
 wire noise_slot_ready=!noise_pending||noise_ready;
 assign request_ready=!rst&&!owner_reset_request&&scan_ready&&bridge_ready&&noise_slot_ready;
 wire admit=request_valid&&request_ready;
 always @(posedge clk_rf)begin
  if(rst)begin noise_pending<=0;noise_key<=0;noise_data<=0;end
  else begin
   if(noise_pending&&noise_ready)noise_pending<=0;
   if(admit)begin noise_pending<=1;noise_key<=request_key;noise_data<=frozen_noise;end
  end
 end
 capture_reset_coordinator reset_control(.clk(clk_rf),.rst(rst),.reset_request(reset_request),
  .producers_idle(producers_idle&&!aux_drain_busy&&(pending==0)&&!reader_busy&&!measurement_valid&&!noise_pending),
  .qualification_idle(bridge_idle),.upload_idle(idle_rf&&fine_idle_rf),.replay_idle(replay_quiescent),
  .owner_epoch(owner_epoch),.owner_reset_request(owner_reset_request),.block_new_work(block_new_work),.busy(reset_busy),.done(reset_done));
 generate if(ONLINE_STATS)begin: online_path
  reg valid_q;reg [255:0] key_q;reg [511:0] stats_q;reg [191:0] peaks_q;reg [7:0] error_q;
  reg identity_ok,window_ok;reg [5:0] trunc_bad;integer n;
  reg [63:0] common_start;reg [14:0] common_count;
  always @*begin
   identity_ok=owner_epoch==request_key[191:128];window_ok=1;trunc_bad=0;
   common_start=start_seq[bank_ids[1:0]*64+:64];common_count=sample_count[bank_ids[1:0]*15+:15];
   if(common_count==0||common_count>16384)window_ok=0;
   for(integer g=0;g<3;g=g+1)begin
    n=g*4+bank_ids[g*2+:2];
    if(!pending[n]||frozen[n]||generation[n*64+:64]!=bank_generations[g*64+:64]||pulse_id[n*64+:64]!=request_key[255:192])identity_ok=0;
    if(start_seq[n*64+:64]!=common_start||sample_count[n*15+:15]!=common_count)window_ok=0;
    trunc_bad[g]=truncated[n];trunc_bad[g+3]=truncated[n];
   end
  end
  assign scan_ready=online_valid&&!valid_q;
  assign reader_busy=valid_q;assign measurement_valid=valid_q;assign measurement_key=key_q;
  assign measurement_data=stats_q;assign measurement_peaks=peaks_q;assign statistics_error=error_q;
  assign pending_stats_enable=0;assign pending_stats_address=0;
  always @(posedge clk_rf)begin
   if(rst)begin valid_q<=0;key_q<=0;stats_q<=0;peaks_q<=0;error_q<=0;end
   else begin
    if(valid_q&&measurement_ready)valid_q<=0;
    if(admit)begin
     valid_q<=1;key_q<=request_key;stats_q<=online_stats;peaks_q<=online_peaks;error_q<=online_error;
     stats_q[296:291]<=online_stats[296:291]|bad_channels|trunc_bad;
     if(!identity_ok||!window_ok||online_error!=0)begin
      stats_q[296:291]<=6'h3f;error_q<=!identity_ok?8'h40:(!window_ok?8'h80:online_error);
     end
    end
   end
  end
 end else begin: diagnostic_scan
 capture_statistics_reader scanner(.clk(clk_rf),.rst(rst),.request_valid(admit),.request_ready(scan_ready),
  .request_bank_ids(bank_ids),.request_generations(bank_generations),.request_key(request_key),.request_bad_channels(bad_channels),
  .pending(pending),.frozen(frozen),.truncated(truncated),.generation(generation),.pulse_id(pulse_id),.start_seq(start_seq),
  .sample_count(sample_count),.owner_epoch(owner_epoch),.abort_request(1'b0),
  .ram_read_enable(pending_stats_enable),.ram_read_address(pending_stats_address),.ram_read_data(pending_stats_data),.ram_read_valid(pending_stats_valid),
  .busy(reader_busy),.result_valid(measurement_valid),.result_ready(measurement_ready),.result_key(measurement_key),.result_stats(measurement_data),
  .result_peaks(measurement_peaks),.result_bank_ids(),.result_generations(),.result_error(statistics_error));
 end endgenerate
 qualification_publish_bridge qualification(.clk(clk_rf),.rst(rst),.quiesce(quiesce),
  .begin_valid(admit),.begin_ready(bridge_ready),.begin_key(request_key),.config_data(config_data),.bank_ids(bank_ids),.bank_generations(bank_generations),.headers(headers),.want_replay(want_replay),
  .measurement_peaks(measurement_peaks),.event_stats(event_stats),.event_peaks(event_peaks),
  .measurement_valid(measurement_valid),.measurement_key(measurement_key),.measurement_data(measurement_data),.measurement_ready(measurement_ready),
  .noise_valid(noise_pending),.noise_key(noise_key),.noise_data(noise_data),.noise_ready(noise_ready),
  .pending(pending),.qualified(qualified),.generation(generation),.pulse_id(pulse_id),.owner_epoch(owner_epoch),
  .stats_valid(main_stats_valid),.stats_good(stats_good),.stats_generation(main_stats_generation),.publish(main_publish),.replay_pin(replay_pin),.discard_pending(discard_pending),
  .event_valid(event_valid),.event_ready(event_ready),.event_published(event_published),.event_rejected(event_rejected),.event_key(event_key),
  .event_bank(event_bank),.event_header(event_header),.event_generation(event_generation),.event_epoch(event_epoch),
  .begin_rejected(),.measurement_rejected(),.noise_rejected(),.idle(bridge_idle));
 wire [3:0] aux_eop_valid,aux_stats_valid,aux_publish;wire [255:0] aux_eop_stop,aux_eop_generation,aux_stats_generation;
 wire [3:0] main_desc_valid;wire [4095:0] main_desc_headers;wire [7:0] main_desc_banks;
 wire [255:0] main_expected_epoch,main_expected_generation;
 wire aux_desc_valid;wire [1023:0] aux_desc_header;wire [1:0] aux_desc_bank;wire [63:0] aux_desc_epoch,aux_desc_generation;
 assign stats_valid={aux_stats_valid,main_stats_valid[11:0]};assign publish={aux_publish,main_publish[11:0]};
 assign stats_generation={aux_stats_generation,main_stats_generation[767:0]};
 assign desc_valid={aux_desc_valid,main_desc_valid[2:0]};assign desc_headers={aux_desc_header,main_desc_headers[3071:0]};
 assign desc_banks={aux_desc_bank,main_desc_banks[5:0]};assign source_expected_epoch={aux_desc_epoch,main_expected_epoch[191:0]};
 assign source_expected_generation={aux_desc_generation,main_expected_generation[191:0]};
 aux_capture_path #(.PRE_SAMPLES(PRE_SAMPLES),.PHYSICAL_MASKS_IN_TEMPLATE(PHYSICAL_MASKS_IN_TEMPLATE)) aux_path(.clk(clk_rf),.rst(rst),
  .armed(armed[15:12]),.pending(pending[15:12]),.frozen(frozen[15:12]),.truncated(truncated[15:12]),
  .generation(generation[1023:768]),.pulse_id(pulse_id[1023:768]),.start_seq(start_seq[1023:768]),.sample_count(sample_count[239:180]),
  .eop_valid(aux_eop_valid),.eop_stop(aux_eop_stop),.eop_generation(aux_eop_generation),
  .stats_valid(aux_stats_valid),.publish(aux_publish),.stats_generation(aux_stats_generation),
  .desc_valid(aux_desc_valid),.desc_header(aux_desc_header),.desc_bank(aux_desc_bank),.desc_epoch(aux_desc_epoch),.desc_generation(aux_desc_generation),
  .desc_ready(desc_ready[3]),.stale_descriptor(stale_descriptor[3]),.*);
 qualification_record_source source(.rst(rst),.desc_valid(main_desc_valid),.desc_headers(main_desc_headers),.desc_banks(main_desc_banks),.source_expected_epoch(main_expected_epoch),.source_expected_generation(main_expected_generation),.*);
 wire [15:0] analysis_pin,analysis_leased,record_leased,fine_read_enable,fine_read_lease;
 wire [207:0] fine_read_address;wire [2047:0] fine_read_data;
 wire ack_analysis;wire [3:0] ack_analysis_bank;wire [63:0] ack_analysis_epoch,ack_analysis_generation;
 generate if(ENABLE_FINE&&ONLINE_STATS)begin: fine_path
  wire fine_result_valid,fine_lost_valid;wire [1023:0] fine_result_data;wire [31:0] fine_errors;
  fine_bank_service #(.PRE_SAMPLES(PRE_SAMPLES)) service(.clk_rf(clk_rf),.clk_mem(clk_mem),.rst_n(rst_n),.admit(admit),
   .bank_ids(bank_ids),.bad_channels(bad_channels),.request_key(request_key),.frozen_noise(frozen_noise),.headers(headers),
   .tops(online_tops),.peaks(online_peaks),.online_stats(online_stats),.online_error(online_error),
   .publish(main_publish),.discard_pending(discard_pending),.analysis_leased(analysis_leased),.record_leased(record_leased),.truncated(truncated),
   .start_seq(start_seq),.generation(generation),.sample_count(sample_count),.analysis_pin(analysis_pin),
   .ack_analysis(ack_analysis),.ack_analysis_bank(ack_analysis_bank),.ack_analysis_epoch(ack_analysis_epoch),.ack_analysis_generation(ack_analysis_generation),
   .idle_rf(fine_idle_rf),.read_enable(fine_read_enable),.read_lease(fine_read_lease),.read_address(fine_read_address),.read_data(fine_read_data),
   .lost_valid(fine_lost_valid),.result_valid(fine_result_valid),.result_data(fine_result_data),.errors(fine_errors));
  fine_result_transport results(.clk_mem(clk_mem),.clk_rf(clk_rf),.rst_n(rst_n),.in_valid(fine_result_valid),.lost_valid(fine_lost_valid),.in_data(fine_result_data),
   .command_valid(fine_command_valid),.command_pop(fine_command_pop),.command_token(fine_command_token),
   .command_ready(fine_command_ready),.response_valid(fine_response_valid),.response_ok(fine_response_ok),.response_data(fine_response_data),.available_rf(fine_available_rf));
 end else begin: no_fine
  assign analysis_pin=0;assign ack_analysis=0;assign ack_analysis_bank=0;assign ack_analysis_epoch=0;assign ack_analysis_generation=0;
  assign fine_idle_rf=1;assign fine_read_enable=0;assign fine_read_lease=0;assign fine_read_address=0;
  assign fine_command_ready=0;assign fine_response_valid=0;assign fine_response_ok=0;assign fine_response_data=0;assign fine_available_rf=0;
 end endgenerate
 capture_record_system #(.PRE_SAMPLES(PRE_SAMPLES),.DETECTOR_LATENCY(DETECTOR_LATENCY),.FIFO_ADDR_W(FIFO_ADDR_W),.STATS_PORT_ENABLED(ONLINE_STATS?0:1),.ENABLE_FINE(ENABLE_FINE&&ONLINE_STATS)) capture(
  .analysis_pin(analysis_pin),.analysis_leased(analysis_leased),.record_leased(record_leased),
  .ack_analysis(ack_analysis),.ack_analysis_bank(ack_analysis_bank),.ack_analysis_epoch(ack_analysis_epoch),.ack_analysis_generation(ack_analysis_generation),
  .fine_read_enable(fine_read_enable),.fine_read_lease(fine_read_lease),.fine_read_address(fine_read_address),.fine_read_data(fine_read_data),
  .clk_rf(clk_rf),.clk_mem(clk_mem),.rst_n(rst_n),.arm_enable(arm_enable&&!block_new_work),.reset_request(owner_reset_request),.replay_quiescent(replay_quiescent&&!reader_busy),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.group_data(group_data),.primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(primary_pulse_id),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(aux_pulse_id),.aux_admitted(aux_admitted),
  .eop_valid({aux_eop_valid,eop_valid[11:0]}),.eop_stop({aux_eop_stop,eop_stop[767:0]}),.eop_generation({aux_eop_generation,eop_generation[767:0]}),
  .discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
  .replay_leased(replay_leased),.ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_generation),
  .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
  .pending_stats_enable(pending_stats_enable),.pending_stats_address(pending_stats_address),.pending_stats_data(pending_stats_data),.pending_stats_valid(pending_stats_valid),
  .desc_valid(desc_valid),.desc_ready(desc_ready),.desc_headers(desc_headers),.desc_banks(desc_banks),.source_expected_epoch(source_expected_epoch),.source_expected_generation(source_expected_generation),.stale_descriptor(stale_descriptor),
  .completion_valid(completion_valid),.completion_error(completion_error),.completion_epoch(completion_epoch),.completion_generation(completion_generation),.completion_group(completion_group),.completion_bank(completion_bank),
  .record_errors(record_errors),.write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),.start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(sample_count),
  .owner_epoch(owner_epoch),.rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.quiesce(quiesce),.idle_rf(idle_rf),.primary_admitted(primary_admitted),
  .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),.m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready),.fifo_occupancy(fifo_occupancy));
endmodule
