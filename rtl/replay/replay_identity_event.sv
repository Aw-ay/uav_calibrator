// One immutable identity record. Caller reserves capture_ready before accepting
// a replay task; token belongs to the shared TX lifecycle/reset domain.
module replay_identity_event(
 input wire clk,rst,capture_valid,event_ready,input wire [1535:0] task_context,input wire [63:0] lifecycle_token,
 output wire capture_ready,output reg capture_rejected,event_valid,output reg [511:0] event_data
);
 import replay_control_layout_pkg::*;
 import replay_identity_event_pkg::*;
 wire [31:0] group_id=task_context[STREAM_GROUP_ID_BIT+:32];
 wire [31:0] bank_id=task_context[BANK_ID_BIT+:32];
 wire context_ok=lifecycle_token!=0&&group_id>=1&&group_id<=4&&bank_id<=3;
 assign capture_ready=!rst&&!event_valid;
 always @(posedge clk)begin
  if(rst)begin capture_rejected<=0;event_valid<=0;event_data<=0;end
  else begin
   capture_rejected<=capture_valid&&(!capture_ready||!context_ok);
   if(event_valid&&event_ready)event_valid<=0;
   if(capture_valid&&capture_ready&&context_ok)begin
    event_valid<=1;event_data<=0;
    event_data[REPLAY_IDENTITY_TAG_OFFSET*8+:32]<=REPLAY_IDENTITY_TAG;
    event_data[REPLAY_IDENTITY_TOKEN_OFFSET*8+:64]<=lifecycle_token;
    event_data[REPLAY_IDENTITY_TASK_ID_OFFSET*8+:64]<=task_context[TASK_ID_BIT+:64];
    event_data[REPLAY_IDENTITY_PULSE_ID_OFFSET*8+:64]<=task_context[PULSE_ID_BIT+:64];
    event_data[REPLAY_IDENTITY_OWNER_EPOCH_OFFSET*8+:64]<=task_context[OWNER_EPOCH_BIT+:64];
    event_data[REPLAY_IDENTITY_GENERATION_OFFSET*8+:64]<=task_context[GENERATION_BIT+:64];
    event_data[REPLAY_IDENTITY_CONFIG_ID_OFFSET*8+:32]<=task_context[CONFIG_ID_BIT+:32];
    event_data[REPLAY_IDENTITY_FIR_ID_OFFSET*8+:32]<=task_context[FIR_ID_BIT+:32];
    event_data[REPLAY_IDENTITY_SOURCE_EPOCH_OFFSET*8+:32]<=task_context[SOURCE_EPOCH_BIT+:32];
    event_data[REPLAY_IDENTITY_GROUP_OFFSET*8+:16]<=group_id[15:0];
    event_data[REPLAY_IDENTITY_BANK_OFFSET*8+:16]<=bank_id[15:0];
   end
  end
 end
endmodule
