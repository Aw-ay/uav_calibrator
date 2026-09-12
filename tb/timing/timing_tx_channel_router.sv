module timing_tx_channel_router(input wire timing_clk,input wire [83:0] stimulus,output wire [266:0] observed);
(* DONT_TOUCH="true" *) reg [83:0] launch;
(* DONT_TOUCH="true" *) reg [266:0] capture;
wire [266:0] result;
always @(posedge timing_clk) begin launch<=stimulus;capture<=result;end
assign observed=capture;
tx_channel_router dut(.clk(timing_clk),.rst(launch[0+: 1]),.in_valid(launch[1+: 1]),.route_commit(launch[2+: 1]),.safe_boundary(launch[3+: 1]),.shadow_select(launch[4+: 8]),.shadow_enable(launch[12+: 8]),.in_hv(launch[20+: 64]),.out_valid(result[0+: 1]),.commit_ack(result[1+: 1]),.commit_rejected(result[2+: 1]),.lane_valid(result[3+: 8]),.out_lanes(result[11+: 256]));
endmodule
