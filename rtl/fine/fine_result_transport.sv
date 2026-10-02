// Mem-domain nonblocking sidecar queue. Commands cross as held transactions;
// head/count/token/data are captured atomically before returning to RF.
module fine_result_transport #(parameter integer ADDR_W=6)(
 input wire clk_mem,clk_rf,rst_n,input wire in_valid,lost_valid,input wire [1023:0] in_data,
 input wire command_valid,command_pop,input wire [63:0] command_token,
 output wire command_ready,output reg response_valid,output reg response_ok,
 output reg [1151:0] response_data,output wire available_rf
);
 (* ASYNC_REG="TRUE" *) reg [1:0] mem_up,rf_up,available_sync;
 reg available_mem;
 always @(posedge clk_mem or negedge rst_n)if(!rst_n)mem_up<=0;else mem_up<={mem_up[0],1'b1};
 always @(posedge clk_rf or negedge rst_n)begin
  if(!rst_n)begin rf_up<=0;available_sync<=0;end
  else begin rf_up<={rf_up[0],1'b1};available_sync<={available_sync[0],available_mem};end
 end
 assign available_rf=available_sync[1];
 localparam DEPTH=1<<ADDR_W;
 reg [1023:0] data_mem[0:DEPTH-1];reg [63:0] token_mem[0:DEPTH-1];
 reg [ADDR_W-1:0] rd,wr;reg [ADDR_W:0] count;reg [31:0] dropped;reg [63:0] next_token;reg exhausted;
 wire req_busy,req_valid,req_take,ret_busy,ret_valid;wire [64:0] req_data;wire [1152:0] ret_data;
 // Capture the held mailbox bus before token comparison and RAM enables.
 // The entire comparison runs in clk_mem, not on the RF-to-mem payload path.
 reg [64:0] command_mem;reg command_pending_mem;
 reg outstanding,reply_pending;reg [1152:0] reply;
 assign command_ready=rf_up[1]&&!outstanding&&!req_busy;
 assign req_take=mem_up[1]&&!command_pending_mem&&!reply_pending&&!ret_busy;
 cdc_mailbox #(.WIDTH(65)) requests(.src_clk(clk_rf),.dst_clk(clk_mem),.rst_n(rst_n),
  .src_send(command_valid&&command_ready),.src_data({command_pop,command_token}),.src_busy(req_busy),.src_done(),
  .dst_valid(req_valid),.dst_data(req_data),.dst_take(req_take));
 cdc_mailbox #(.WIDTH(1153)) replies(.src_clk(clk_mem),.dst_clk(clk_rf),.rst_n(rst_n),
  .src_send(reply_pending&&!ret_busy),.src_data(reply),.src_busy(ret_busy),.src_done(),
  .dst_valid(ret_valid),.dst_data(ret_data),.dst_take(rf_up[1]));
 wire pop=command_pending_mem&&command_mem[64]&&count!=0&&command_mem[63:0]==token_mem[rd];
 wire push=in_valid&&!exhausted&&(count<DEPTH||pop);
 wire [1:0] losses={1'b0,lost_valid}+{1'b0,(in_valid&&!push)};
 wire [32:0] drop_sum={1'b0,dropped}+losses;
 always @(posedge clk_rf)begin
  if(!rf_up[1])begin outstanding<=0;response_valid<=0;response_ok<=0;response_data<=0;end
  else begin
   response_valid<=0;
   if(command_valid&&command_ready)outstanding<=1;
   if(ret_valid)begin response_valid<=1;{response_ok,response_data}<=ret_data;outstanding<=0;end
  end
 end
 always @(posedge clk_mem)begin
  if(!mem_up[1])begin available_mem<=0;rd<=0;wr<=0;count<=0;dropped<=0;next_token<=1;exhausted<=0;reply_pending<=0;reply<=0;command_mem<=0;command_pending_mem<=0;end
  else begin
   available_mem<=count!=0;
   if(reply_pending&&!ret_busy)reply_pending<=0;
   if(req_valid&&req_take)begin command_mem<=req_data;command_pending_mem<=1;end
   if(command_pending_mem)begin
    command_pending_mem<=0;
    reply<={(!command_mem[64]||pop),(count!=0?data_mem[rd]:1024'd0),(count!=0?token_mem[rd]:64'd0),dropped,{{(31-ADDR_W){1'b0}},count}};
    reply_pending<=1;
   end
   if(push)begin data_mem[wr]<=in_data;token_mem[wr]<=next_token;wr<=wr+1'b1;
    if(next_token==64'hffffffffffffffff)exhausted<=1;else next_token<=next_token+1'b1;
   end
   if(losses!=0)dropped<=drop_sum[32]?32'hffffffff:drop_sum[31:0];
   if(pop)rd<=rd+1'b1;
   case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:begin end endcase
  end
 end
endmodule
