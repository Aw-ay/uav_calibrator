// RF-domain binding to the real capture owner. No software-supplied lease truth.
module capture_replay_binding(
 input wire clk,rst,input wire [1535:0] lookup_task,active_task,input wire active,
 input wire [63:0] owner_epoch,input wire [15:0] frozen,qualified,replay_leased,
 input wire [1023:0] generation,pulse_id,start_seq,input wire [239:0] sample_count,
 output wire [63:0] current_generation,output wire bank_frozen,data_ready,bank_qualified,lease_pinned,
 input wire ram_en,input wire [31:0] ram_group,ram_bank,input wire [13:0] ram_addr,
 output reg [15:0] replay_enable,output reg [223:0] replay_address,
 input wire [1023:0] replay_data,input wire [15:0] replay_valid,
 output wire ram_response_valid,output wire [63:0] ram_data,
 input wire token_valid,input wire [63:0] token_owner_epoch,token_generation,
 input wire [31:0] token_group,token_bank,token_consumer,
 output wire token_ready,ack_replay,output wire [3:0] ack_replay_bank,
 output wire [63:0] ack_replay_epoch,ack_replay_generation,output reg [31:0] rejected_tokens
);
 import replay_control_layout_pkg::*;
 wire [1535:0] context_task=active?active_task:lookup_task;
 wire [31:0] group_id=context_task[STREAM_GROUP_ID_BIT+:32],bank_id=context_task[BANK_ID_BIT+:32];
 wire context_bounds=group_id>=1&&group_id<=4&&bank_id<4;
 wire [3:0] slot=((group_id-1)<<2)|bank_id;
 assign current_generation=context_bounds?generation[slot*64+:64]:64'd0;
 assign bank_frozen=context_bounds&&frozen[slot];
 assign bank_qualified=context_bounds&&qualified[slot];
 assign lease_pinned=context_bounds&&replay_leased[slot];
 assign data_ready=bank_frozen&&context_task[OWNER_EPOCH_BIT+:64]==owner_epoch&&
  context_task[GENERATION_BIT+:64]==current_generation&&context_task[PULSE_ID_BIT+:64]==pulse_id[slot*64+:64]&&
  context_task[START_SEQ_BIT+:64]==start_seq[slot*64+:64]&&
  context_task[START_PTR_BIT+:32]=={18'd0,start_seq[slot*64+:14]}&&
  context_task[SAMPLE_COUNT_BIT+:32]>0&&context_task[SAMPLE_COUNT_BIT+:32]<={17'd0,sample_count[slot*15+:15]};
 wire read_bounds=ram_group>=1&&ram_group<=4&&ram_bank<4;
 wire [3:0] read_slot=((ram_group-1)<<2)|ram_bank;
 reg response_pending;reg [3:0] response_slot;
 always @*begin
  replay_enable=0;replay_address=0;
  if(!rst&&ram_en&&read_bounds&&frozen[read_slot]&&replay_leased[read_slot])begin
   replay_enable[read_slot]=1;replay_address[read_slot*14+:14]=ram_addr;
  end
 end
 always @(posedge clk)begin
  if(rst)begin response_pending<=0;response_slot<=0;rejected_tokens<=0;end
  else begin
   response_pending<=|replay_enable;if(|replay_enable)response_slot<=read_slot;
   if(token_valid&&token_ready&&!ack_replay)rejected_tokens<=rejected_tokens+1'b1;
  end
 end
 assign ram_response_valid=response_pending&&replay_valid[response_slot];
 assign ram_data=replay_data[response_slot*64+:64];
 wire token_bounds=token_group>=1&&token_group<=4&&token_bank<4;
 assign ack_replay_bank=((token_group-1)<<2)|token_bank;
 assign token_ready=!rst;
 assign ack_replay=token_valid&&token_ready&&token_bounds&&token_consumer==2&&
  frozen[ack_replay_bank]&&replay_leased[ack_replay_bank]&&token_owner_epoch==owner_epoch&&
  token_generation==generation[ack_replay_bank*64+:64];
 assign ack_replay_epoch=token_owner_epoch;
 assign ack_replay_generation=token_generation;
endmodule
