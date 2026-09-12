module tx_cal_executor(
 input wire clk,rst,in_valid,cal_valid,
 input wire signed [15:0] in_i,in_q,dc_i,dc_q,
 input wire signed [17:0] gain_i,gain_q,
 output wire out_valid,out_cal_valid,
 output wire signed [15:0] out_i,out_q,output wire saturated);
 complex_cal_core #(.DC_POST(1)) core(.*);
endmodule
