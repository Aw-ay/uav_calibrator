// Shared arithmetic only: calibration qualification remains an explicit input.
module complex_cal_core #(parameter integer DC_POST=0)(
 input wire clk,rst,in_valid,cal_valid,
 input wire signed [15:0] in_i,in_q,dc_i,dc_q,
 input wire signed [17:0] gain_i,gain_q,
 output reg out_valid,out_cal_valid,
 output reg signed [15:0] out_i,out_q,output reg saturated);
 wire signed [16:0] xi=DC_POST ? $signed(in_i) : $signed({in_i[15],in_i})-$signed({dc_i[15],dc_i});
 wire signed [16:0] xq=DC_POST ? $signed(in_q) : $signed({in_q[15],in_q})-$signed({dc_q[15],dc_q});
 wire signed [34:0] ii=xi*gain_i, qq=xq*gain_q, iq=xi*gain_q, qi=xq*gain_i;
 wire signed [36:0] add_i=DC_POST ? ($signed({{21{dc_i[15]}},dc_i})<<<16) : 37'sd0;
 wire signed [36:0] add_q=DC_POST ? ($signed({{21{dc_q[15]}},dc_q})<<<16) : 37'sd0;
 wire signed [36:0] acc_i=$signed(ii)-$signed(qq)+add_i;
 wire signed [36:0] acc_q=$signed(iq)+$signed(qi)+add_q;
 wire signed [15:0] yi,yq;wire si,sq;
 fixed_round_sat #(.IN_W(37)) qi_round(acc_i,yi,si),qq_round(acc_q,yq,sq);
 always @(posedge clk) begin
   if(rst) begin out_valid<=0;out_cal_valid<=0;out_i<=0;out_q<=0;saturated<=0;end
   else begin
     out_valid<=in_valid;out_cal_valid<=in_valid&&cal_valid;
     out_i<=in_valid&&cal_valid ? yi : 16'sd0;
     out_q<=in_valid&&cal_valid ? yq : 16'sd0;
     saturated<=in_valid&&cal_valid&&(si||sq);
   end
 end
endmodule
