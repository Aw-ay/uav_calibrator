// All eight DAC lanes preserved; every input launched and every output captured.
module timing_tx_processing_chain(input wire timing_clk,input wire [869:0] stimulus,output wire [1351:0] observed);
(* DONT_TOUCH="true" *) reg [869:0] launch;
(* DONT_TOUCH="true" *) reg [1351:0] capture;
wire [1351:0] result;
always @(posedge timing_clk)begin launch<=stimulus;capture<=result;end
assign observed=capture;
tx_processing_chain dut(.clk_rf(timing_clk),.rst(launch[0+:1]),.mode_request(launch[1+:1]),.safe_boundary(launch[2+:1]),.rf_permit(launch[3+:1]),.hard_fault(launch[4+:1]),.single_antenna_ota(launch[5+:1]),.config_commit(launch[6+:1]),.requested_mode(launch[7+:3]),.route_select(launch[10+:8]),.route_enable(launch[18+:8]),.cal_valid(launch[26+:8]),.dc_i(launch[34+:128]),.dc_q(launch[162+:128]),.gain_i(launch[290+:144]),.gain_q(launch[434+:144]),.config_id(launch[578+:32]),.live_data(launch[610+:64]),.drfm_data(launch[674+:64]),.dds_data(launch[738+:64]),.awg_data(launch[802+:64]),.live_valid(launch[866+:1]),.drfm_valid(launch[867+:1]),.dds_valid(launch[868+:1]),.awg_valid(launch[869+:1]),.active_mode(result[0+:3]),.mode_accepted(result[3+:1]),.mode_rejected(result[4+:1]),.pipeline_ready(result[5+:1]),.config_accepted(result[6+:1]),.config_rejected(result[7+:1]),.active_config_id(result[8+:32]),.calibrated_i(result[40+:128]),.calibrated_q(result[168+:128]),.calibrated_valid(result[296+:8]),.calibration_saturated(result[304+:8]),.tx_saturated(result[312+:8]),.native_dac_valid(result[320+:8]),.native_dac_data(result[328+:1024]));
endmodule
