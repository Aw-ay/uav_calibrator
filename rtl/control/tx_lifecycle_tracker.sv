// One serial task, then one immutable record. A sink fence is an abstract
// exact-token protocol, not a fabricated RFDC/RF acknowledgement.
module tx_lifecycle_tracker(
 input wire clk,rst,start_valid,source_done,source_drained,tail_empty,time_valid,require_sink_ack,
 input wire [31:0] source,command_sequence,config_id,cancel_reason,
 input wire [63:0] gsc,sink_ack_token,
 input wire sink_fence_ready,sink_ack_valid,event_ready,
 output wire start_ready,busy,sink_fence_valid,output reg start_rejected,protocol_error,event_valid,
 output wire [63:0] sink_fence_token,output reg [511:0] event_data
);
 import tx_lifecycle_event_pkg::*;
 reg active,done_seen,digital_seen,fence_sent,ack_seen,need_ack,time_known,exhausted;
 reg [31:0] source_hold,sequence_hold,config_hold,reason_hold;
 reg [63:0] token_hold,next_token,accept_gsc,drain_gsc;
 wire valid_source=source>=TX_LIFECYCLE_SOURCE_DDS&&source<=TX_LIFECYCLE_SOURCE_REPLAY;
 wire boundary=active&&(done_seen||source_done)&&source_drained&&tail_empty;
 wire digital_ready=digital_seen||boundary;
 assign busy=active;
 assign start_ready=!rst&&!active&&!event_valid&&!exhausted;
 assign sink_fence_valid=!rst&&active&&need_ack&&digital_ready&&!fence_sent;
 assign sink_fence_token=token_hold;
 wire fence_take=sink_fence_valid&&sink_fence_ready;
 wire ack_ok=sink_ack_valid&&active&&need_ack&&(fence_sent||fence_take)&&sink_ack_token==token_hold;
 wire retire=active&&digital_ready&&(!need_ack||ack_seen||ack_ok);
 wire [63:0] final_drain=digital_seen?drain_gsc:gsc;
 wire times_ok=time_known&&time_valid&&gsc>=accept_gsc&&gsc>=final_drain;
 wire [31:0] final_reason=reason_hold!=0?reason_hold:cancel_reason;
 reg [511:0] record;
 always @* begin
  record=0;
  record[TX_LIFECYCLE_TAG_OFFSET*8+:32]=TX_LIFECYCLE_TAG;
  record[TX_LIFECYCLE_FLAGS_OFFSET*8+:32]=TX_LIFECYCLE_DIGITAL_DRAINED|
   (times_ok?TX_LIFECYCLE_TIME_VALID:0)|((need_ack&&(ack_seen||ack_ok))?TX_LIFECYCLE_SINK_CONFIRMED:0);
  record[TX_LIFECYCLE_SOURCE_OFFSET*8+:32]=source_hold;
  record[TX_LIFECYCLE_REASON_OFFSET*8+:32]=final_reason;
  record[TX_LIFECYCLE_COMMAND_SEQUENCE_OFFSET*8+:32]=sequence_hold;
  record[TX_LIFECYCLE_CONFIG_ID_OFFSET*8+:32]=config_hold;
  record[TX_LIFECYCLE_TOKEN_OFFSET*8+:64]=token_hold;
  record[TX_LIFECYCLE_ACCEPT_GSC_OFFSET*8+:64]=times_ok?accept_gsc:0;
  record[TX_LIFECYCLE_DRAIN_GSC_OFFSET*8+:64]=times_ok?final_drain:0;
  record[TX_LIFECYCLE_RETIRE_GSC_OFFSET*8+:64]=times_ok?gsc:0;
 end
 always @(posedge clk)begin
  if(rst)begin
   active<=0;done_seen<=0;digital_seen<=0;fence_sent<=0;ack_seen<=0;need_ack<=0;time_known<=0;exhausted<=0;
   source_hold<=0;sequence_hold<=0;config_hold<=0;reason_hold<=0;token_hold<=0;next_token<=1;accept_gsc<=0;drain_gsc<=0;
   start_rejected<=0;protocol_error<=0;event_valid<=0;event_data<=0;
  end else begin
   start_rejected<=start_valid&&(!start_ready||!valid_source);
   protocol_error<=sink_ack_valid&&!ack_ok;
   if(event_valid&&event_ready)event_valid<=0;
   if(active)begin
    if(source_done)done_seen<=1;
    if(!time_valid||gsc<accept_gsc)time_known<=0;
    if(reason_hold==0&&cancel_reason!=0)reason_hold<=cancel_reason;
    if(boundary&&!digital_seen)begin digital_seen<=1;drain_gsc<=gsc;end
    if(fence_take)fence_sent<=1;
    if(ack_ok)ack_seen<=1;
   end
   if(retire)begin active<=0;event_valid<=1;event_data<=record;end
   if(start_valid&&start_ready&&valid_source)begin
    active<=1;done_seen<=0;digital_seen<=0;fence_sent<=0;ack_seen<=0;need_ack<=require_sink_ack;time_known<=time_valid;
    source_hold<=source;sequence_hold<=command_sequence;config_hold<=config_id;reason_hold<=cancel_reason;
    token_hold<=next_token;accept_gsc<=gsc;drain_gsc<=0;
    if(next_token==64'hffffffffffffffff)exhausted<=1;else next_token<=next_token+1'b1;
   end
  end
 end
endmodule
