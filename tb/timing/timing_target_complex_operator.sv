module timing_target_complex_operator(input wire timing_clk,input wire [246:0] stimulus,output wire [66:0] observed);
(* DONT_TOUCH="true" *) reg [246:0] launch;
(* DONT_TOUCH="true" *) reg [66:0] capture;
wire [66:0] result;
always @(posedge timing_clk) begin launch<=stimulus;capture<=result;end
assign observed=capture;
target_complex_operator dut(.clk(timing_clk),.rst(launch[0+: 1]),.in_valid(launch[1+: 1]),.model_valid(launch[2+: 1]),.in_hv(launch[3+: 64]),.matrix(launch[67+: 144]),.phase_i(launch[211+: 18]),.phase_q(launch[229+: 18]),.out_valid(result[0+: 1]),.out_model_valid(result[1+: 1]),.out_hv(result[2+: 64]),.saturated(result[66+: 1]));
endmodule
