// Signed-magnitude wrapper. Keeps all256-bit sign normalization off the carry path.
module fine_signed_math #(parameter integer FAST_MATH=0)(
 input wire clk,rst,abort,req_valid,output wire req_ready,
 input wire [1:0] operation,input wire round_nearest,
 input wire [255:0] magnitude_a,magnitude_b,input wire negative_a,negative_b,
 output reg result_valid,input wire result_ready,output reg [255:0] magnitude,
 output reg negative,fault
);
 localparam IDLE=0,ISSUE=1,WAIT_RESULT=2;
 reg [1:0] state,op;reg [255:0] a,b;reg sign_out,reverse_on_borrow,rounding;
 wire ready,valid,bad;wire [255:0] value;
 generate if(FAST_MATH)begin: fast_arithmetic
 fine_fast_math core(.clk(clk),.rst(rst),.abort(abort),.req_valid(state==ISSUE),.req_ready(ready),
  .operation(op),.round_nearest(rounding),.operand_a(a),.operand_b(b),
  .result_valid(valid),.result_ready(state==WAIT_RESULT),.result(value),.fault(bad));
 end else begin: serial_arithmetic
 fine_wide_math core(.clk(clk),.rst(rst),.abort(abort),.req_valid(state==ISSUE),.req_ready(ready),
  .operation(op),.round_nearest(rounding),.operand_a(a),.operand_b(b),
  .result_valid(valid),.result_ready(state==WAIT_RESULT),.result(value),.fault(bad));
 end endgenerate
 assign req_ready=state==IDLE&&!result_valid&&!rst&&!abort;
 wire sb=negative_b^(operation==1);
 always @(posedge clk)begin
  if(rst||abort)begin state<=IDLE;result_valid<=0;magnitude<=0;negative<=0;fault<=0;end
  else begin
   if(result_valid&&result_ready)result_valid<=0;
   case(state)
    IDLE:if(req_valid&&req_ready)begin
     a<=magnitude_a;b<=magnitude_b;rounding<=round_nearest;reverse_on_borrow<=0;
     if(operation<2)begin
      op<=negative_a==sb?0:1;sign_out<=negative_a;reverse_on_borrow<=negative_a!=sb;
     end else begin op<=operation;sign_out<=negative_a^negative_b;end
     state<=ISSUE;
    end
    ISSUE:if(ready)state<=WAIT_RESULT;
    WAIT_RESULT:if(valid)begin
     if(bad&&reverse_on_borrow)begin a<=b;b<=a;sign_out<=!sign_out;reverse_on_borrow<=0;state<=ISSUE;end
     else begin magnitude<=value;negative<=sign_out&&(value!=0);fault<=bad;result_valid<=1;state<=IDLE;end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
