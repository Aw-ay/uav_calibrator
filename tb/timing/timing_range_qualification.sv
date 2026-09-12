// Timing fixture only; adds launch/capture cycles, not a production wrapper.
module timing_range_qualification(
 input wire timing_clk,
 input wire [275:0] energy,
 input wire [275:0] noise_energy,
 input wire [31:0] min_snr_q16,
 input wire [5:0] bad_channels,
 input wire [5:0] cal_valid,
 input wire [5:0] noise_valid,
 input wire [5:0] linearity_known,
 input wire [5:0] linearity_pass,
 input wire  context_valid,
 input wire  threshold_valid,
 input wire  rank_valid,
 input wire [2:0] frozen_stats_done,
 input wire [5:0] gain_order,
 input wire [14:0] sample_count,
 output wire [5:0] qualified,
 output wire [47:0] reasons,
 output wire  selected_valid,
 output wire [1:0] selected_range
);
 (* DONT_TOUCH="true" *) reg [275:0] launch_energy;
 always @(posedge timing_clk) launch_energy<=energy;
 (* DONT_TOUCH="true" *) reg [275:0] launch_noise_energy;
 always @(posedge timing_clk) launch_noise_energy<=noise_energy;
 (* DONT_TOUCH="true" *) reg [31:0] launch_min_snr_q16;
 always @(posedge timing_clk) launch_min_snr_q16<=min_snr_q16;
 (* DONT_TOUCH="true" *) reg [5:0] launch_bad_channels;
 always @(posedge timing_clk) launch_bad_channels<=bad_channels;
 (* DONT_TOUCH="true" *) reg [5:0] launch_cal_valid;
 always @(posedge timing_clk) launch_cal_valid<=cal_valid;
 (* DONT_TOUCH="true" *) reg [5:0] launch_noise_valid;
 always @(posedge timing_clk) launch_noise_valid<=noise_valid;
 (* DONT_TOUCH="true" *) reg [5:0] launch_linearity_known;
 always @(posedge timing_clk) launch_linearity_known<=linearity_known;
 (* DONT_TOUCH="true" *) reg [5:0] launch_linearity_pass;
 always @(posedge timing_clk) launch_linearity_pass<=linearity_pass;
 (* DONT_TOUCH="true" *) reg  launch_context_valid;
 always @(posedge timing_clk) launch_context_valid<=context_valid;
 (* DONT_TOUCH="true" *) reg  launch_threshold_valid;
 always @(posedge timing_clk) launch_threshold_valid<=threshold_valid;
 (* DONT_TOUCH="true" *) reg  launch_rank_valid;
 always @(posedge timing_clk) launch_rank_valid<=rank_valid;
 (* DONT_TOUCH="true" *) reg [2:0] launch_frozen_stats_done;
 always @(posedge timing_clk) launch_frozen_stats_done<=frozen_stats_done;
 (* DONT_TOUCH="true" *) reg [5:0] launch_gain_order;
 always @(posedge timing_clk) launch_gain_order<=gain_order;
 (* DONT_TOUCH="true" *) reg [14:0] launch_sample_count;
 always @(posedge timing_clk) launch_sample_count<=sample_count;
 wire [5:0] dut_qualified;
 (* DONT_TOUCH="true" *) reg [5:0] capture_qualified;
 always @(posedge timing_clk) capture_qualified<=dut_qualified;
 assign qualified=capture_qualified;
 wire [47:0] dut_reasons;
 (* DONT_TOUCH="true" *) reg [47:0] capture_reasons;
 always @(posedge timing_clk) capture_reasons<=dut_reasons;
 assign reasons=capture_reasons;
 wire  dut_selected_valid;
 (* DONT_TOUCH="true" *) reg  capture_selected_valid;
 always @(posedge timing_clk) capture_selected_valid<=dut_selected_valid;
 assign selected_valid=capture_selected_valid;
 wire [1:0] dut_selected_range;
 (* DONT_TOUCH="true" *) reg [1:0] capture_selected_range;
 always @(posedge timing_clk) capture_selected_range<=dut_selected_range;
 assign selected_range=capture_selected_range;
 range_qualification dut(
 .energy(launch_energy),
 .noise_energy(launch_noise_energy),
 .min_snr_q16(launch_min_snr_q16),
 .bad_channels(launch_bad_channels),
 .cal_valid(launch_cal_valid),
 .noise_valid(launch_noise_valid),
 .linearity_known(launch_linearity_known),
 .linearity_pass(launch_linearity_pass),
 .context_valid(launch_context_valid),
 .threshold_valid(launch_threshold_valid),
 .rank_valid(launch_rank_valid),
 .frozen_stats_done(launch_frozen_stats_done),
 .gain_order(launch_gain_order),
 .sample_count(launch_sample_count),
 .qualified(dut_qualified),
 .reasons(dut_reasons),
 .selected_valid(dut_selected_valid),
 .selected_range(dut_selected_range)
 );
endmodule
