// Timing fixture only; adds launch/capture cycles, not a production wrapper.
module timing_noise_snapshot(
 input wire timing_clk,
 input wire  rst,
 input wire  clear_estimate,
 input wire  offpulse_enable,
 input wire  snapshot_request,
 input wire  result_ready,
 input wire [95:0] iq_i,
 input wire [95:0] iq_q,
 input wire [5:0] sample_good,
 input wire [4:0] ewma_shift,
 input wire [31:0] max_age_cycles,
 input wire [63:0] pulse_id,
 input wire [63:0] context_version,
 output wire  snapshot_ready,
 output wire  result_valid,
 output wire  rejected,
 output wire [63:0] result_id,
 output wire [63:0] result_context,
 output wire [191:0] noise_power,
 output wire [5:0] noise_known
);
 (* DONT_TOUCH="true" *) reg  launch_rst;
 always @(posedge timing_clk) launch_rst<=rst;
 (* DONT_TOUCH="true" *) reg  launch_clear_estimate;
 always @(posedge timing_clk) launch_clear_estimate<=clear_estimate;
 (* DONT_TOUCH="true" *) reg  launch_offpulse_enable;
 always @(posedge timing_clk) launch_offpulse_enable<=offpulse_enable;
 (* DONT_TOUCH="true" *) reg  launch_snapshot_request;
 always @(posedge timing_clk) launch_snapshot_request<=snapshot_request;
 (* DONT_TOUCH="true" *) reg  launch_result_ready;
 always @(posedge timing_clk) launch_result_ready<=result_ready;
 (* DONT_TOUCH="true" *) reg [95:0] launch_iq_i;
 always @(posedge timing_clk) launch_iq_i<=iq_i;
 (* DONT_TOUCH="true" *) reg [95:0] launch_iq_q;
 always @(posedge timing_clk) launch_iq_q<=iq_q;
 (* DONT_TOUCH="true" *) reg [5:0] launch_sample_good;
 always @(posedge timing_clk) launch_sample_good<=sample_good;
 (* DONT_TOUCH="true" *) reg [4:0] launch_ewma_shift;
 always @(posedge timing_clk) launch_ewma_shift<=ewma_shift;
 (* DONT_TOUCH="true" *) reg [31:0] launch_max_age_cycles;
 always @(posedge timing_clk) launch_max_age_cycles<=max_age_cycles;
 (* DONT_TOUCH="true" *) reg [63:0] launch_pulse_id;
 always @(posedge timing_clk) launch_pulse_id<=pulse_id;
 (* DONT_TOUCH="true" *) reg [63:0] launch_context_version;
 always @(posedge timing_clk) launch_context_version<=context_version;
 wire  dut_snapshot_ready;
 (* DONT_TOUCH="true" *) reg  capture_snapshot_ready;
 always @(posedge timing_clk) capture_snapshot_ready<=dut_snapshot_ready;
 assign snapshot_ready=capture_snapshot_ready;
 wire  dut_result_valid;
 (* DONT_TOUCH="true" *) reg  capture_result_valid;
 always @(posedge timing_clk) capture_result_valid<=dut_result_valid;
 assign result_valid=capture_result_valid;
 wire  dut_rejected;
 (* DONT_TOUCH="true" *) reg  capture_rejected;
 always @(posedge timing_clk) capture_rejected<=dut_rejected;
 assign rejected=capture_rejected;
 wire [63:0] dut_result_id;
 (* DONT_TOUCH="true" *) reg [63:0] capture_result_id;
 always @(posedge timing_clk) capture_result_id<=dut_result_id;
 assign result_id=capture_result_id;
 wire [63:0] dut_result_context;
 (* DONT_TOUCH="true" *) reg [63:0] capture_result_context;
 always @(posedge timing_clk) capture_result_context<=dut_result_context;
 assign result_context=capture_result_context;
 wire [191:0] dut_noise_power;
 (* DONT_TOUCH="true" *) reg [191:0] capture_noise_power;
 always @(posedge timing_clk) capture_noise_power<=dut_noise_power;
 assign noise_power=capture_noise_power;
 wire [5:0] dut_noise_known;
 (* DONT_TOUCH="true" *) reg [5:0] capture_noise_known;
 always @(posedge timing_clk) capture_noise_known<=dut_noise_known;
 assign noise_known=capture_noise_known;
 noise_snapshot dut(
 .clk(timing_clk),
 .rst(launch_rst),
 .clear_estimate(launch_clear_estimate),
 .offpulse_enable(launch_offpulse_enable),
 .snapshot_request(launch_snapshot_request),
 .result_ready(launch_result_ready),
 .iq_i(launch_iq_i),
 .iq_q(launch_iq_q),
 .sample_good(launch_sample_good),
 .ewma_shift(launch_ewma_shift),
 .max_age_cycles(launch_max_age_cycles),
 .pulse_id(launch_pulse_id),
 .context_version(launch_context_version),
 .snapshot_ready(dut_snapshot_ready),
 .result_valid(dut_result_valid),
 .rejected(dut_rejected),
 .result_id(dut_result_id),
 .result_context(dut_result_context),
 .noise_power(dut_noise_power),
 .noise_known(dut_noise_known)
 );
endmodule
