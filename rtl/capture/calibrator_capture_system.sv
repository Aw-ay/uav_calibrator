// Onset snapshot -> producer ownership -> actual header generation -> RAW upload.
// Producer errors remain explicit held records; accepting an error is not a RAW ACK.
module calibrator_capture_system #(
 parameter integer PRE_SAMPLES=250,DETECTOR_LATENCY=1,FIFO_ADDR_W=12,PHYSICAL_MASKS_IN_TEMPLATE=0,ONLINE_STATS=0,ENABLE_FINE=0
)(
 input wire fine_command_valid,fine_command_pop,input wire [63:0] fine_command_token,
 output wire fine_command_ready,fine_response_valid,fine_response_ok,fine_available_rf,
 output wire [1151:0] fine_response_data,
 input wire [5:0] online_sample_good,input wire [13:0] onset_eop_hold,
 input wire body_end_valid,input wire [63:0] body_end_pulse_id,body_end_owner_epoch,body_end_seq,
 input wire aux_request_valid,aux_qualified,aux_meta_pop,
 input wire [31:0] aux_request_count,input wire [63:0] aux_request_tx_token,aux_sample_gsc,aux_meta_pop_key,
 input wire [127:0] aux_context,input wire [1023:0] aux_template_header,
 output wire aux_request_ready,aux_request_accepted,aux_request_rejected,aux_meta_valid,aux_meta_pop_ok,aux_busy,
 output wire [767:0] aux_meta_data,
 output wire pdw_valid,output wire [255:0] pdw_key,output wire [1023:0] pdw_header,output wire [511:0] pdw_stats,output wire [191:0] pdw_peaks,
 output wire [15:0] replay_leased,
 input wire clk_rf,clk_mem,rst_n,arm_enable,reset_request,replay_quiescent,
 input wire sample_valid,input wire [63:0] sample_seq,input wire [255:0] group_data,
 input wire onset_valid,output wire onset_ready,onset_accepted,onset_rejected,
 input wire [63:0] onset_seq,onset_gsc,onset_pulse_id,config_version,
 input wire [1023:0] onset_config,onset_metadata,input wire [255:0] onset_noise,
 input wire [5:0] onset_bad_channels,input wire onset_want_replay,
 input wire eop_event_valid,input wire [63:0] eop_event_pulse_id,eop_event_owner_epoch,eop_event_stop,
 input wire [5:0] eop_event_bad_channels,output wire eop_accepted,eop_rejected,
 output wire producer_error_valid,producer_error_bound,input wire producer_error_ready,
 output wire [255:0] producer_error_key,output wire [5:0] producer_error_bank_ids,
 output wire [191:0] producer_error_generations,output wire [7:0] producer_error_reason,
 output wire [31:0] onset_reject_count,eop_reject_count,context_error_count,
 output wire header_error,
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
 wire primary_trigger;wire [63:0] primary_onset,primary_pulse_id;
 wire [15:0] eop_valid;wire [1023:0] eop_stop,eop_generation;
 wire producer_valid,producer_ready,tracker_idle,admission_idle,producers_idle;
 wire [255:0] producer_key,producer_noise;
 wire [1023:0] producer_config,producer_metadata;
 wire [5:0] producer_bank_ids,producer_bad_channels;
 wire [191:0] producer_generations,producer_starts;
 wire [44:0] producer_counts;wire [63:0] producer_onset_seq,producer_onset_gsc;
 wire producer_want_replay;
 wire request_valid,request_ready,want_replay;
 wire [255:0] request_key,frozen_noise;wire [1023:0] config_data;wire [3071:0] headers;
 wire [5:0] bank_ids,bad_channels;wire [191:0] bank_generations;
 wire stats_onset_ready,tracker_onset_ready,online_idle,online_valid;
 wire [191:0] online_tops;wire [511:0] online_stats;wire [191:0] online_peaks;wire [7:0] online_error;
 assign onset_ready=tracker_onset_ready&&stats_onset_ready;
 assign producers_idle=tracker_idle&&admission_idle&&online_idle;
 generate if(ONLINE_STATS)begin: online_acquisition
  capture_online_statistics online(.clk(clk_rf),.rst(rst),.sample_valid(sample_valid),.sample_seq(sample_seq),.group_data(group_data),.sample_good(online_sample_good),
   .onset_valid(onset_valid&&tracker_onset_ready),.onset_ready(stats_onset_ready),.onset_key({owner_epoch,onset_pulse_id}),.onset_seq(onset_seq),
   .onset_noise(onset_noise[191:0]),.onset_eop_hold(onset_eop_hold),
   .body_end_valid(body_end_valid),.body_end_key({body_end_owner_epoch,body_end_pulse_id}),.body_end_seq(body_end_seq),
   .cancel_valid(producer_error_valid),.cancel_key({producer_error_key[191:128],producer_error_key[255:192]}),
   .query_key({request_key[191:128],request_key[255:192]}),.query_valid(online_valid),.query_ready(request_valid&&request_ready),
   .query_tops(online_tops),.query_stats(online_stats),.query_peaks(online_peaks),.query_error(online_error),.idle(online_idle));
 end else begin: legacy_statistics
  assign stats_onset_ready=1;assign online_idle=1;assign online_valid=0;assign online_stats=0;assign online_peaks=0;assign online_tops=0;assign online_error=0;
 end endgenerate
 capture_producer_tracker tracker(.clk(clk_rf),.rst(rst),.block_new_work(block_new_work),
  .onset_valid(onset_valid&&stats_onset_ready),.onset_ready(tracker_onset_ready),.onset_accepted(onset_accepted),.onset_rejected(onset_rejected),
  .onset_seq(onset_seq),.onset_gsc(onset_gsc),.onset_pulse_id(onset_pulse_id),.config_version(config_version),
  .onset_config(onset_config),.onset_metadata(onset_metadata),.onset_noise(onset_noise),.onset_bad_channels(onset_bad_channels),
  .onset_want_replay(onset_want_replay),.request_want_replay(producer_want_replay),
  .primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(primary_pulse_id),.primary_admitted(primary_admitted),
  .armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.generation(generation),.pulse_id(pulse_id),.start_seq(start_seq),.sample_count(sample_count),.owner_epoch(owner_epoch),
  .eop_event_valid(eop_event_valid),.eop_event_pulse_id(eop_event_pulse_id),.eop_event_owner_epoch(eop_event_owner_epoch),.eop_event_stop(eop_event_stop),.eop_event_bad_channels(eop_event_bad_channels),
  .eop_accepted(eop_accepted),.eop_rejected(eop_rejected),.eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),
  .request_valid(producer_valid),.request_ready(producer_ready),.request_key(producer_key),.request_noise(producer_noise),.request_config(producer_config),.request_metadata(producer_metadata),
  .request_bank_ids(producer_bank_ids),.request_bad_channels(producer_bad_channels),.request_generations(producer_generations),.request_starts(producer_starts),.request_counts(producer_counts),.request_onset_seq(producer_onset_seq),.request_onset_gsc(producer_onset_gsc),
  .error_valid(producer_error_valid),.error_ready(producer_error_ready),.error_key(producer_error_key),.error_bank_ids(producer_error_bank_ids),.error_generations(producer_error_generations),.error_reason(producer_error_reason),.error_bound(producer_error_bound),
  .occupied(),.producers_idle(tracker_idle),.onset_reject_count(onset_reject_count),.eop_reject_count(eop_reject_count),.context_error_count(context_error_count));
 capture_admission_bridge #(.PHYSICAL_MASKS_IN_TEMPLATE(PHYSICAL_MASKS_IN_TEMPLATE)) admission(.clk(clk_rf),.rst(rst),.in_valid(producer_valid),.in_ready(producer_ready),
  .in_key(producer_key),.in_noise(producer_noise),.in_config(producer_config),.in_metadata(producer_metadata),
  .in_bank_ids(producer_bank_ids),.in_bad_channels(producer_bad_channels),.in_generations(producer_generations),.in_start_seq(producer_starts),.in_sample_count(producer_counts),
  .in_onset_seq(producer_onset_seq),.in_onset_gsc(producer_onset_gsc),.in_want_replay(producer_want_replay),
  .out_valid(request_valid),.out_ready(request_ready),.out_key(request_key),.out_noise(frozen_noise),.out_config(config_data),.out_headers(headers),
  .out_bank_ids(bank_ids),.out_bad_channels(bad_channels),.out_generations(bank_generations),.out_want_replay(want_replay),.header_error(header_error),.idle(admission_idle));
 calibrator_capture_pipeline #(.PRE_SAMPLES(PRE_SAMPLES),.DETECTOR_LATENCY(DETECTOR_LATENCY),.FIFO_ADDR_W(FIFO_ADDR_W),.PHYSICAL_MASKS_IN_TEMPLATE(PHYSICAL_MASKS_IN_TEMPLATE),.ONLINE_STATS(ONLINE_STATS),.ENABLE_FINE(ENABLE_FINE)) backend(.*);
endmodule
