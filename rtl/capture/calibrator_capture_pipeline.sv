// Normal-mode capture backend: complete PENDING-window scan -> qualification ->
// selected RAW record. Request metadata/noise must be frozen at pulse onset.
// Existing captures can submit scans during reset drainage; only NEW capture
// admissions are blocked. Upstream retains unsubmitted capture descriptions.
module calibrator_capture_pipeline #(
 parameter integer PRE_SAMPLES=250,DETECTOR_LATENCY=0,FIFO_ADDR_W=12
)(
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
 wire rst=!rf_up[1];
 wire [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending,pending_stats_enable,pending_stats_valid;
 wire [1023:0] stats_generation,pending_stats_data;wire [223:0] pending_stats_address;
 wire [3:0] desc_valid,desc_ready,stale_descriptor;wire [4095:0] desc_headers;wire [7:0] desc_banks;
 wire [255:0] source_expected_epoch,source_expected_generation;
 wire owner_reset_request,bridge_idle,scan_ready,bridge_ready,reader_busy;
 wire measurement_valid,measurement_ready;wire [255:0] measurement_key;wire [511:0] measurement_data;
 reg noise_pending;reg [255:0] noise_key,noise_data;wire noise_ready;
 wire event_valid,event_ready,event_published,event_rejected;
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
  .producers_idle(producers_idle&&(pending==0)&&!reader_busy&&!measurement_valid&&!noise_pending),
  .qualification_idle(bridge_idle),.upload_idle(idle_rf),.replay_idle(replay_quiescent),
  .owner_epoch(owner_epoch),.owner_reset_request(owner_reset_request),.block_new_work(block_new_work),.busy(reset_busy),.done(reset_done));
 capture_statistics_reader scanner(.clk(clk_rf),.rst(rst),.request_valid(admit),.request_ready(scan_ready),
  .request_bank_ids(bank_ids),.request_generations(bank_generations),.request_key(request_key),.request_bad_channels(bad_channels),
  .pending(pending),.frozen(frozen),.truncated(truncated),.generation(generation),.pulse_id(pulse_id),.start_seq(start_seq),
  .sample_count(sample_count),.owner_epoch(owner_epoch),.abort_request(1'b0),
  .ram_read_enable(pending_stats_enable),.ram_read_address(pending_stats_address),.ram_read_data(pending_stats_data),.ram_read_valid(pending_stats_valid),
  .busy(reader_busy),.result_valid(measurement_valid),.result_ready(measurement_ready),.result_key(measurement_key),.result_stats(measurement_data),
  .result_peaks(),.result_bank_ids(),.result_generations(),.result_error(statistics_error));
 qualification_publish_bridge qualification(.clk(clk_rf),.rst(rst),.quiesce(quiesce),
  .begin_valid(admit),.begin_ready(bridge_ready),.begin_key(request_key),.config_data(config_data),.bank_ids(bank_ids),.bank_generations(bank_generations),.headers(headers),.want_replay(want_replay),
  .measurement_valid(measurement_valid),.measurement_key(measurement_key),.measurement_data(measurement_data),.measurement_ready(measurement_ready),
  .noise_valid(noise_pending),.noise_key(noise_key),.noise_data(noise_data),.noise_ready(noise_ready),
  .pending(pending),.qualified(qualified),.generation(generation),.pulse_id(pulse_id),.owner_epoch(owner_epoch),
  .stats_valid(stats_valid),.stats_good(stats_good),.stats_generation(stats_generation),.publish(publish),.replay_pin(replay_pin),.discard_pending(discard_pending),
  .event_valid(event_valid),.event_ready(event_ready),.event_published(event_published),.event_rejected(event_rejected),.event_key(event_key),
  .event_bank(event_bank),.event_header(event_header),.event_generation(event_generation),.event_epoch(event_epoch),
  .begin_rejected(),.measurement_rejected(),.noise_rejected(),.idle(bridge_idle));
 qualification_record_source source(.rst(rst),.*);
 capture_record_system #(.PRE_SAMPLES(PRE_SAMPLES),.DETECTOR_LATENCY(DETECTOR_LATENCY),.FIFO_ADDR_W(FIFO_ADDR_W),.STATS_PORT_ENABLED(1)) capture(
  .clk_rf(clk_rf),.clk_mem(clk_mem),.rst_n(rst_n),.arm_enable(arm_enable&&!block_new_work),.reset_request(owner_reset_request),.replay_quiescent(replay_quiescent&&!reader_busy),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.group_data(group_data),.primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(primary_pulse_id),
  .aux_trigger(1'b0),.aux_onset(64'd0),.aux_pulse_id(64'd0),.aux_admitted(),
  .eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),
  .discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
  .ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_generation),
  .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
  .pending_stats_enable(pending_stats_enable),.pending_stats_address(pending_stats_address),.pending_stats_data(pending_stats_data),.pending_stats_valid(pending_stats_valid),
  .desc_valid(desc_valid),.desc_ready(desc_ready),.desc_headers(desc_headers),.desc_banks(desc_banks),.source_expected_epoch(source_expected_epoch),.source_expected_generation(source_expected_generation),.stale_descriptor(stale_descriptor),
  .completion_valid(completion_valid),.completion_error(completion_error),.completion_epoch(completion_epoch),.completion_generation(completion_generation),.completion_group(completion_group),.completion_bank(completion_bank),
  .record_errors(record_errors),.write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),.start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(sample_count),
  .owner_epoch(owner_epoch),.rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.quiesce(quiesce),.idle_rf(idle_rf),.primary_admitted(primary_admitted),
  .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),.m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready),.fifo_occupancy(fifo_occupancy));
endmodule
