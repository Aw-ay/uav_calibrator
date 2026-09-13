// Shared RF-domain ownership for DDS/AWG/REPLAY. Upstream must reserve
// admission_ready before actual source acceptance. One token/reset domain.
module tx_task_lifecycle(
 input wire clk,rst,dds_started,awg_started,replay_started,dds_done,awg_done,generated_drained,
 input wire replay_reader_retired,replay_dsp_busy,replay_out_valid,replay_cancelled,
 input wire [7:0] replay_reader_status,input wire [1535:0] replay_context,
 input wire [63:0] gsc,sink_ack_token,input wire time_valid,tail_empty,require_sink_ack,
 input wire sink_fence_ready,sink_ack_valid,event_ready,input wire [31:0] command_sequence,config_id,cancel_reason,
 output wire admission_ready,protocol_error,sink_fence_valid,event_valid,
 output wire [63:0] sink_fence_token,output wire [511:0] event_data
);
 import tx_lifecycle_event_pkg::*;
 wire tracker_ready,observer_ready,identity_ready;
 reg identity_capture_pending,identity_publish_pending,local_error,replay_error_seen;
 reg [31:0] active_source;
 wire any_start=dds_started||awg_started||replay_started;
 wire single_start=!(dds_started&&awg_started)&&!(dds_started&&replay_started)&&!(awg_started&&replay_started);
 assign admission_ready=tracker_ready&&observer_ready&&identity_ready&&!identity_capture_pending&&!identity_publish_pending;
 wire take_start=any_start&&single_start&&admission_ready;
 wire [31:0] source_now=replay_started?TX_LIFECYCLE_SOURCE_REPLAY:(dds_started?TX_LIFECYCLE_SOURCE_DDS:TX_LIFECYCLE_SOURCE_AWG);
 wire is_replay=active_source==TX_LIFECYCLE_SOURCE_REPLAY;
 wire observed_valid,observer_rejected,observer_error;
 wire [1535:0] observed_context;wire [7:0] observed_status;
 wire identity_valid,identity_take_ready,identity_rejected;
 wire [511:0] identity_data;
 wire retired_valid,retired_ready,tracker_rejected,tracker_error;wire [511:0] retired_data;
 wire [31:0] effective_reason=cancel_reason!=0?cancel_reason:
  (!take_start&&is_replay&&(replay_error_seen||replay_cancelled||(replay_reader_retired&&replay_reader_status!=0))?TX_LIFECYCLE_REASON_REPLAY_ABORT:32'd0);
 assign protocol_error=local_error||observer_rejected||observer_error||identity_rejected||tracker_rejected||tracker_error;
 always @(posedge clk)begin
  if(rst)begin identity_capture_pending<=0;identity_publish_pending<=0;local_error<=0;active_source<=0;replay_error_seen<=0;end
  else begin
   local_error<=any_start&&!take_start;
   if(identity_capture_pending&&identity_ready)identity_capture_pending<=0;
   if(identity_valid&&identity_take_ready)identity_publish_pending<=0;
   if(is_replay&&(replay_cancelled||(replay_reader_retired&&replay_reader_status!=0)))replay_error_seen<=1;
   if(take_start)begin
    active_source<=source_now;replay_error_seen<=0;
    if(replay_started)begin identity_capture_pending<=1;identity_publish_pending<=1;end
   end
  end
 end
 replay_drain_observer observer(.clk(clk),.rst(rst),.task_started(take_start&&replay_started),.task_context(replay_context),
  .reader_retired(replay_reader_retired),.reader_status(replay_reader_status),.dsp_busy(replay_dsp_busy),.dsp_out_valid(replay_out_valid),
  .drained_ready(1'b1),.start_ready(observer_ready),.start_rejected(observer_rejected),.protocol_error(observer_error),
  .drained_valid(observed_valid),.drained_context(observed_context),.drained_status(observed_status));
 replay_identity_event identity(.clk(clk),.rst(rst),.capture_valid(identity_capture_pending),.capture_ready(identity_ready),
  .capture_rejected(identity_rejected),.task_context(observed_context),.lifecycle_token(sink_fence_token),
  .event_ready(identity_take_ready),.event_valid(identity_valid),.event_data(identity_data));
 tx_lifecycle_tracker tracker(.clk(clk),.rst(rst),.start_valid(take_start),.start_ready(tracker_ready),.start_rejected(tracker_rejected),.busy(),
  .source(source_now),.command_sequence(replay_started?32'd0:command_sequence),.config_id(config_id),.cancel_reason(effective_reason),
  .source_done(is_replay?observed_valid:(dds_done||awg_done)),.source_drained(is_replay?(!replay_dsp_busy&&!replay_out_valid):generated_drained),
  .tail_empty(tail_empty),.time_valid(time_valid),.gsc(gsc),.require_sink_ack(require_sink_ack),
  .sink_fence_ready(sink_fence_ready),.sink_ack_valid(sink_ack_valid),.sink_ack_token(sink_ack_token),
  .sink_fence_valid(sink_fence_valid),.sink_fence_token(sink_fence_token),.protocol_error(tracker_error),
  .event_valid(retired_valid),.event_data(retired_data),.event_ready(retired_ready&&!identity_publish_pending));
 // Identity is admitted first. The registered arbiter cannot preempt a held
// identity with its retirement, even under arbitrary downstream backpressure.
 event_priority_arbiter records(.clk(clk),.rst(rst),.fault_valid(identity_valid),.fault_data(identity_data),.fault_ready(identity_take_ready),
  .normal_valid(retired_valid&&!identity_publish_pending),.normal_data(retired_data),.normal_ready(retired_ready),
  .out_valid(event_valid),.out_data(event_data),.out_ready(event_ready),.out_is_fault());
endmodule
