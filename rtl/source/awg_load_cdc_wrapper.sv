// Serialized, acknowledged AWG control transactions across clk_ctrl/clk_rf.
// op0 BEGIN(length,crc); op1 WRITE(data); op2 COMMIT; op3 invalid.
// Uses bundled-data toggle mailboxes: payload held stable until synchronized ACK.
module awg_load_cdc_wrapper #(parameter integer DEPTH=16384)(
 input wire clk_ctrl,clk_rf,rst_n,ctrl_valid,input wire [1:0] ctrl_op,
 input wire [31:0] ctrl_length,ctrl_crc32c,input wire [63:0] ctrl_data,
 output wire ctrl_ready,output reg ctrl_done,ctrl_error,output reg [1:0] ctrl_done_op,
 output reg ctrl_loaded,ctrl_active_valid,
 input wire safe_boundary,play,output wire active_valid,playing,out_valid,out_last,
 output wire [63:0] out_data);
 (* ASYNC_REG="TRUE" *) reg [1:0] ctrl_reset_sync,rf_reset_sync;
 always @(posedge clk_ctrl or negedge rst_n)
  if(!rst_n)ctrl_reset_sync<=0;else ctrl_reset_sync<={ctrl_reset_sync[0],1'b1};
 always @(posedge clk_rf or negedge rst_n)
  if(!rst_n)rf_reset_sync<=0;else rf_reset_sync<={rf_reset_sync[0],1'b1};
 wire crn=ctrl_reset_sync[1],rrn=rf_reset_sync[1];
 reg awaiting_response;
 wire req_busy,req_valid,req_take;wire [129:0] req_payload;
 wire resp_busy,resp_valid,resp_send;wire [4:0] resp_payload;
 reg [4:0] response_hold;reg [1:0] op_hold;
 reg [1:0] state;
 localparam IDLE=0,OBSERVE=1,WAIT_COMMIT=2,RESPOND=3;
 wire launch=req_valid&&(state==IDLE)&&rrn;
 assign req_take=launch;
 assign ctrl_ready=crn&&!req_busy&&!awaiting_response;
 awg_load_cdc_mailbox #(.WIDTH(130)) request_box(
  .src_clk(clk_ctrl),.dst_clk(clk_rf),.src_rst_n(crn),.dst_rst_n(rrn),
  .src_send(ctrl_valid&&ctrl_ready),.src_data({ctrl_op,ctrl_length,ctrl_crc32c,ctrl_data}),
  .src_busy(req_busy),.dst_valid(req_valid),.dst_data(req_payload),.dst_take(req_take));
 awg_load_cdc_mailbox #(.WIDTH(5)) response_box(
  .src_clk(clk_rf),.dst_clk(clk_ctrl),.src_rst_n(rrn),.dst_rst_n(crn),
  .src_send(resp_send),.src_data(response_hold),.src_busy(resp_busy),
  .dst_valid(resp_valid),.dst_data(resp_payload),.dst_take(resp_valid));
 assign resp_send=(state==RESPOND)&&!resp_busy;
 wire [1:0] request_op=req_payload[129:128];
 wire core_ready,core_loaded,core_ack,core_error,core_active,core_playing,core_valid,core_last;
 wire [63:0] core_data;
 awg_reader #(.DEPTH(DEPTH)) core(
  .clk(clk_rf),.rst(!rrn),.load_begin(launch&&request_op==0),
  .load_length(req_payload[127:96]),.load_crc32c(req_payload[95:64]),
  .load_valid(launch&&request_op==1),.load_data(req_payload[63:0]),
  .load_ready(core_ready),.loaded(core_loaded),.commit(launch&&request_op==2),
  .safe_boundary(safe_boundary),.commit_ack(core_ack),.error(core_error),
  .active_valid(core_active),.play(play&&rrn),.playing(core_playing),
  .out_valid(core_valid),.out_last(core_last),.out_data(core_data));
 assign active_valid=rst_n&&rrn&&core_active;
 assign playing=rst_n&&rrn&&core_playing;
 assign out_valid=rst_n&&rrn&&core_valid;
 assign out_last=rst_n&&rrn&&core_last;
 assign out_data=(rst_n&&rrn)?core_data:64'd0;
 always @(posedge clk_ctrl or negedge crn)begin
  if(!crn)begin awaiting_response<=0;ctrl_done<=0;ctrl_error<=0;ctrl_done_op<=0;ctrl_loaded<=0;ctrl_active_valid<=0;end
  else begin
   ctrl_done<=0;ctrl_error<=0;
   if(ctrl_valid&&ctrl_ready)awaiting_response<=1;
   if(resp_valid)begin
    awaiting_response<=0;ctrl_done<=1;
    {ctrl_done_op,ctrl_error,ctrl_loaded,ctrl_active_valid}<=resp_payload;
   end
  end
 end
 always @(posedge clk_rf or negedge rrn)begin
  if(!rrn)begin state<=IDLE;op_hold<=0;response_hold<=0;end
  else case(state)
   IDLE:if(launch)begin op_hold<=request_op;state<=OBSERVE;end
   OBSERVE:begin
    if(core_error||op_hold==3)begin response_hold<={op_hold,1'b1,core_loaded,core_active};state<=RESPOND;end
    else if(op_hold==2)state<=WAIT_COMMIT;
    else begin response_hold<={op_hold,1'b0,core_loaded,core_active};state<=RESPOND;end
   end
   WAIT_COMMIT:if(core_ack)begin response_hold<={op_hold,1'b0,core_loaded,core_active};state<=RESPOND;end
   RESPOND:if(!resp_busy)state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule

// Both resets assert together; each deasserts synchronously in its own domain.
// Physical implementation must bound payload settling before destination capture.
module awg_load_cdc_mailbox #(parameter integer WIDTH=32)(
 input wire src_clk,dst_clk,src_rst_n,dst_rst_n,src_send,
 input wire [WIDTH-1:0] src_data,output wire src_busy,
 output wire dst_valid,output wire [WIDTH-1:0] dst_data,input wire dst_take);
 reg [WIDTH-1:0] payload;reg request,ack,pending;
 (* DONT_TOUCH="TRUE" *) reg [WIDTH-1:0] destination_payload;
 (* ASYNC_REG="TRUE" *) reg ack_meta,ack_sync,req_meta,req_sync;
 assign src_busy=request!=ack_sync;
 assign dst_valid=pending;
 assign dst_data=destination_payload;
 always @(posedge src_clk or negedge src_rst_n)begin
  if(!src_rst_n)begin payload<=0;request<=0;ack_meta<=0;ack_sync<=0;end
  else begin
   ack_meta<=ack;ack_sync<=ack_meta;
   if(src_send&&!src_busy)begin payload<=src_data;request<=~request;end
  end
 end
 always @(posedge dst_clk or negedge dst_rst_n)begin
  if(!dst_rst_n)begin req_meta<=0;req_sync<=0;ack<=0;pending<=0;destination_payload<=0;end
  else begin
   req_meta<=request;req_sync<=req_meta;
   if(req_sync!=ack&&!pending)begin destination_payload<=payload;pending<=1;end
   if(pending&&dst_take)begin ack<=req_sync;pending<=0;end
  end
 end
endmodule
