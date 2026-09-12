// 512-bit event transport: bundled-data CDC mailbox plus bounded ctrl queue.
// EVENT_LATCH snapshots the head; EVENT_POP removes only a latched head.
// Source valid is a one-cycle attempt. A non-ready attempt increments drops.
// Coordinated hard reset discards queued events; soft capture reset must drain.
module event_mailbox #(parameter integer ADDR_W=4)(
 input wire src_clk,ctrl_clk,rst_n,event_valid,
 input wire [511:0] event_data,
 output wire event_ready,
 output reg [31:0] dropped_events,
 input wire latch_head,pop,input wire [3:0] word_index,
 output wire [31:0] word_data,event_count,
 output reg latched_valid,command_rejected
);
 localparam integer DEPTH=1<<ADDR_W;
 (* ASYNC_REG="TRUE" *) reg [1:0] src_up,ctrl_up;
 always @(posedge src_clk or negedge rst_n)if(!rst_n)src_up<=0;else src_up<={src_up[0],1'b1};
 always @(posedge ctrl_clk or negedge rst_n)if(!rst_n)ctrl_up<=0;else ctrl_up<={ctrl_up[0],1'b1};
 wire mailbox_busy,incoming;wire [511:0] incoming_data;
 reg [511:0] memory[0:DEPTH-1],snapshot;
 reg [ADDR_W-1:0] wr_ptr,rd_ptr;reg [ADDR_W:0] count;
 wire take=ctrl_up[1]&&count<DEPTH;
 wire push=incoming&&take;
 wire remove=pop&&!latch_head&&latched_valid&&count!=0;
 assign event_ready=src_up[1]&&!mailbox_busy;
 assign event_count={{(31-ADDR_W){1'b0}},count};
 assign word_data=latched_valid?snapshot[word_index*32+:32]:32'd0;
 cdc_mailbox #(.WIDTH(512)) transport(.src_clk(src_clk),.dst_clk(ctrl_clk),.rst_n(rst_n),
  .src_send(event_valid&&event_ready),.src_data(event_data),.src_busy(mailbox_busy),.src_done(),
  .dst_valid(incoming),.dst_data(incoming_data),.dst_take(take));
 always @(posedge src_clk or negedge rst_n)begin
  if(!rst_n)dropped_events<=0;
  else if(src_up[1]&&event_valid&&!event_ready&&dropped_events!=32'hffffffff)dropped_events<=dropped_events+1'b1;
 end
 always @(posedge ctrl_clk or negedge rst_n)begin
  if(!rst_n)begin wr_ptr<=0;rd_ptr<=0;count<=0;snapshot<=0;latched_valid<=0;command_rejected<=0;end
  else if(!ctrl_up[1])begin wr_ptr<=0;rd_ptr<=0;count<=0;snapshot<=0;latched_valid<=0;command_rejected<=0;end
  else begin
   command_rejected<=0;
   if(push)begin memory[wr_ptr]<=incoming_data;wr_ptr<=wr_ptr+1'b1;end
   if(latch_head&&pop)command_rejected<=1;
   else if(latch_head)begin
    if(count==0)command_rejected<=1;
    else begin snapshot<=memory[rd_ptr];latched_valid<=1;end
   end else if(pop)begin
    if(!latched_valid||count==0)command_rejected<=1;
    else begin rd_ptr<=rd_ptr+1'b1;latched_valid<=0;end
   end
   case({push,remove})
    2'b10:count<=count+1'b1;
    2'b01:count<=count-1'b1;
    default:begin end
   endcase
  end
 end
endmodule
