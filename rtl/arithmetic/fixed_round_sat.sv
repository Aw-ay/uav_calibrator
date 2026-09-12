// Signed convergent rounding (ties to even), followed by signed saturation.
module fixed_round_sat #(
 parameter integer IN_W=48, OUT_W=16, SHIFT=16
)(input wire signed [IN_W-1:0] value,
 output wire signed [OUT_W-1:0] result, output wire sat);
 wire signed [IN_W:0] extended = {value[IN_W-1],value};
 wire signed [IN_W:0] base = extended >>> SHIFT;
 wire up;
 generate if (SHIFT==0) begin : no_shift
   assign up=1'b0;
 end else begin : rounding
   localparam [SHIFT-1:0] HALF = {1'b1,{(SHIFT-1){1'b0}}};
   assign up=(value[SHIFT-1:0]>HALF) || ((value[SHIFT-1:0]==HALF)&&base[0]);
 end endgenerate
 wire signed [IN_W:0] rounded=base+$signed({{IN_W{1'b0}},up});
 localparam signed [IN_W:0] HI=( {{IN_W{1'b0}},1'b1} << (OUT_W-1))-1;
 localparam signed [IN_W:0] LO=-( {{IN_W{1'b0}},1'b1} << (OUT_W-1));
 assign sat=rounded>HI || rounded<LO;
 assign result=rounded>HI ? HI[OUT_W-1:0] : rounded<LO ? LO[OUT_W-1:0] : rounded[OUT_W-1:0];
 initial begin
   if(IN_W<OUT_W || OUT_W<2 || SHIFT<0 || SHIFT>=IN_W) $fatal(1,"fixed_round_sat illegal widths");
 end
endmodule
