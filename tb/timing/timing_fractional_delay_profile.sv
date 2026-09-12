module timing_fractional_delay_profile(input wire timing_clk,input wire [75:0] stimulus,output wire [108:0] observed);
(* DONT_TOUCH="true" *) reg [75:0] launch;
(* DONT_TOUCH="true" *) reg [108:0] capture;
wire [108:0] result;
always @(posedge timing_clk) begin launch<=stimulus;capture<=result;end
assign observed=capture;
fractional_delay_profile dut(.clk(timing_clk),.rst(launch[0+: 1]),.in_valid(launch[1+: 1]),.profile_commit(launch[2+: 1]),.safe_boundary(launch[3+: 1]),.shadow_phase(launch[4+: 8]),.shadow_version(launch[12+: 32]),.in_i(launch[44+: 16]),.in_q(launch[60+: 16]),.out_valid(result[0+: 1]),.out_coeff_valid(result[1+: 1]),.saturated(result[2+: 1]),.out_i(result[3+: 16]),.out_q(result[19+: 16]),.commit_ack(result[35+: 1]),.commit_rejected(result[36+: 1]),.active_phase(result[37+: 8]),.active_version(result[45+: 32]),.table_version(result[77+: 32]));
endmodule
