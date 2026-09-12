module timing_pulse_detector(input wire timing_clk,input wire [233:0] stimulus,output wire [363:0] observed);
(* DONT_TOUCH="true" *) reg [233:0] launch;
(* DONT_TOUCH="true" *) reg [363:0] capture;
wire [363:0] result;
always @(posedge timing_clk)begin launch<=stimulus;capture<=result;end
assign observed=capture;
pulse_detector dut(.clk(timing_clk),.rst(launch[0+:1]),.sample_valid(launch[1+:1]),.time_valid(launch[2+:1]),.source_valid(launch[3+:1]),.sample_seq(launch[4+:64]),.iq(launch[68+:64]),.cfg_enable(launch[132+:1]),.cfg_validated(launch[133+:1]),.cfg_on_power(launch[134+:33]),.cfg_off_power(launch[167+:33]),.cfg_eop_hold(launch[200+:14]),.cfg_max_body(launch[214+:14]),.noise_qualified(launch[228+:1]),.cfg_noise_shift(launch[229+:5]),.active(result[0+:1]),.onset_valid(result[1+:1]),.event_valid(result[2+:1]),.event_precise(result[3+:1]),.event_truncated(result[4+:1]),.onset_seq(result[5+:64]),.event_onset_seq(result[69+:64]),.event_end_seq(result[133+:64]),.event_reason(result[197+:4]),.sample_power(result[201+:33]),.noise_power(result[234+:33]),.noise_valid(result[267+:1]),.onset_count(result[268+:32]),.pulse_count(result[300+:32]),.abort_count(result[332+:32]));
endmodule
