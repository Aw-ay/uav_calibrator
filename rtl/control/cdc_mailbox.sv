// Bundled-data mailbox. Both clocks must see coordinated reset assertion;
// deassert rst_n synchronously to each clock at integration. Source payload is
// held until destination consume and the synchronized acknowledgement returns.
module cdc_mailbox #(parameter integer WIDTH=32)(
 input wire src_clk,dst_clk,rst_n,input wire src_send,
 input wire [WIDTH-1:0] src_data,output wire src_busy,output reg src_done,
 output wire dst_valid,output wire [WIDTH-1:0] dst_data,input wire dst_take);
 reg [WIDTH-1:0] payload; reg request,ack;
 (* ASYNC_REG="TRUE" *) reg ack_meta,ack_sync,req_meta,req_sync;
 reg ack_seen;
 assign src_busy=request!=ack_sync;
 assign dst_valid=req_sync!=ack;
 assign dst_data=payload;
 always @(posedge src_clk or negedge rst_n) begin
  if(!rst_n)begin payload<=0;request<=0;ack_meta<=0;ack_sync<=0;ack_seen<=0;src_done<=0;end
  else begin
   ack_meta<=ack;ack_sync<=ack_meta;src_done<=ack_sync!=ack_seen;ack_seen<=ack_sync;
   if(src_send&&!src_busy)begin payload<=src_data;request<=~request;end
  end
 end
 always @(posedge dst_clk or negedge rst_n) begin
  if(!rst_n)begin req_meta<=0;req_sync<=0;ack<=0;end
  else begin req_meta<=request;req_sync<=req_meta;if(dst_valid&&dst_take)ack<=req_sync;end
 end
endmodule
