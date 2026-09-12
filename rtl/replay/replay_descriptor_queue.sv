// Bounded synchronous logical FIFO. No RAW RAM write or bank-return outputs.
// Reset only after external quiesce/drain; retire is actual-reader completion.
module replay_descriptor_queue #(parameter integer DEPTH=4)(
 input wire clk,rst,push_valid,input wire [1535:0] push_task,
 output reg push_accepted,push_rejected,output reg [7:0] push_reason,
 output wire head_valid,output wire [1535:0] head_task,
 input wire evaluation_valid,head_legal,input wire [7:0] head_reason,
 input wire reader_ready,output wire dispatch_valid,output wire [1535:0] dispatch_task,
 output reg rejected_valid,output reg [1535:0] rejected_task,output reg [7:0] reject_reason,input wire reject_ready,
 input wire retire_valid,input wire [1535:0] retire_task,output reg retire_rejected,
 output reg inflight,output wire [31:0] queued_count
);
 import replay_control_layout_pkg::*;
 localparam integer PTR_BITS=DEPTH<=1?1:$clog2(DEPTH);
 reg [1535:0] entries[0:DEPTH-1];
 reg [PTR_BITS-1:0] rd_ptr,wr_ptr;
 reg [31:0] used;
 reg [15:0] outstanding;
 reg [1535:0] active_task;
 wire [31:0] push_group=push_task[STREAM_GROUP_ID_BIT+:32];
 wire [31:0] push_bank=push_task[BANK_ID_BIT+:32];
 wire push_bounds=push_group>=1 && push_group<=4 && push_bank<4;
 wire [3:0] push_slot=((push_group-1)<<2)+push_bank;
 wire [3:0] active_slot=((active_task[STREAM_GROUP_ID_BIT+:32]-1)<<2)+active_task[BANK_ID_BIT+:32];
 wire [3:0] reject_slot=((rejected_task[STREAM_GROUP_ID_BIT+:32]-1)<<2)+rejected_task[BANK_ID_BIT+:32];
 wire enqueue=push_valid && push_bounds && used<DEPTH && !outstanding[push_slot];
 wire reject_head=head_valid && evaluation_valid && !head_legal && !rejected_valid && !inflight;
 wire remove_head=dispatch_valid || reject_head;
 wire retire_match=inflight && retire_task[OWNER_EPOCH_BIT+:64]==active_task[OWNER_EPOCH_BIT+:64] &&
  retire_task[GENERATION_BIT+:64]==active_task[GENERATION_BIT+:64] && retire_task[STREAM_GROUP_ID_BIT+:32]==active_task[STREAM_GROUP_ID_BIT+:32] &&
  retire_task[BANK_ID_BIT+:32]==active_task[BANK_ID_BIT+:32] && retire_task[TASK_ID_BIT+:64]==active_task[TASK_ID_BIT+:64];
 assign head_valid=used!=0;
 assign head_task=head_valid?entries[rd_ptr]:1536'b0;
 assign dispatch_valid=!rst && head_valid && evaluation_valid && head_legal && !inflight && !rejected_valid && reader_ready;
 assign dispatch_task=head_task;
 assign queued_count=used;
 always @(posedge clk) begin
  if(rst) begin
   rd_ptr<=0;wr_ptr<=0;used<=0;outstanding<=0;active_task<=0;inflight<=0;
   rejected_valid<=0;rejected_task<=0;reject_reason<=0;push_accepted<=0;push_rejected<=0;push_reason<=0;retire_rejected<=0;
  end else begin
   push_accepted<=0;push_rejected<=0;retire_rejected<=0;
   if(push_valid) begin
    if(enqueue) begin
     entries[wr_ptr]<=push_task;wr_ptr<=wr_ptr==DEPTH-1?0:wr_ptr+1'b1;
     outstanding[push_slot]<=1;push_accepted<=1;push_reason<=0;
    end else begin
     push_rejected<=1;push_reason<=!push_bounds?5:(outstanding[push_slot]?15:1);
    end
   end
   case({enqueue,remove_head})
    2'b10: used<=used+1;
    2'b01: used<=used-1;
    default: begin end
   endcase
   if(remove_head) rd_ptr<=rd_ptr==DEPTH-1?0:rd_ptr+1'b1;
   if(dispatch_valid) begin active_task<=head_task;inflight<=1;end
   if(reject_head) begin rejected_valid<=1;rejected_task<=head_task;reject_reason<=head_reason;end
   if(rejected_valid && reject_ready) begin rejected_valid<=0;outstanding[reject_slot]<=0;end
   if(retire_valid) begin
    if(retire_match) begin inflight<=0;outstanding[active_slot]<=0;end
    else retire_rejected<=1;
   end
  end
 end
endmodule
