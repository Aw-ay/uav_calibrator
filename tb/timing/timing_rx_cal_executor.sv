module timing_rx_cal_executor(input wire timing_clk,input wire [102:0] stimulus,output wire [34:0] observed);
(* DONT_TOUCH="true" *) reg [102:0] launch;
(* DONT_TOUCH="true" *) reg [34:0] capture;
wire [34:0] result;
always @(posedge timing_clk) begin launch<=stimulus;capture<=result;end
assign observed=capture;
rx_cal_executor dut(.clk(timing_clk),.rst(launch[0+: 1]),.in_valid(launch[1+: 1]),.cal_valid(launch[2+: 1]),.in_i(launch[3+: 16]),.in_q(launch[19+: 16]),.dc_i(launch[35+: 16]),.dc_q(launch[51+: 16]),.gain_i(launch[67+: 18]),.gain_q(launch[85+: 18]),.out_valid(result[0+: 1]),.out_cal_valid(result[1+: 1]),.out_i(result[2+: 16]),.out_q(result[18+: 16]),.saturated(result[34+: 1]));
endmodule
