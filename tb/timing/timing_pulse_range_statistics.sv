// Timing fixture only; adds launch/capture cycles, not a production wrapper.
module timing_pulse_range_statistics(
 input wire timing_clk,
 input wire  rst,
 input wire  start,
 input wire  sample_enable,
 input wire  finish,
 input wire  result_ready,
 input wire [63:0] pulse_id,
 input wire [95:0] iq_i,
 input wire [95:0] iq_q,
 input wire [5:0] sample_good,
 input wire [5:0] late_bad,
 output wire  ready,
 output wire  busy,
 output wire  result_valid,
 output wire  rejected,
 output wire [63:0] result_id,
 output wire [191:0] peak_power,
 output wire [275:0] energy,
 output wire [14:0] sample_count,
 output wire [5:0] bad_channels,
 output wire  overflow
);
 (* DONT_TOUCH="true" *) reg  launch_rst;
 always @(posedge timing_clk) launch_rst<=rst;
 (* DONT_TOUCH="true" *) reg  launch_start;
 always @(posedge timing_clk) launch_start<=start;
 (* DONT_TOUCH="true" *) reg  launch_sample_enable;
 always @(posedge timing_clk) launch_sample_enable<=sample_enable;
 (* DONT_TOUCH="true" *) reg  launch_finish;
 always @(posedge timing_clk) launch_finish<=finish;
 (* DONT_TOUCH="true" *) reg  launch_result_ready;
 always @(posedge timing_clk) launch_result_ready<=result_ready;
 (* DONT_TOUCH="true" *) reg [63:0] launch_pulse_id;
 always @(posedge timing_clk) launch_pulse_id<=pulse_id;
 (* DONT_TOUCH="true" *) reg [95:0] launch_iq_i;
 always @(posedge timing_clk) launch_iq_i<=iq_i;
 (* DONT_TOUCH="true" *) reg [95:0] launch_iq_q;
 always @(posedge timing_clk) launch_iq_q<=iq_q;
 (* DONT_TOUCH="true" *) reg [5:0] launch_sample_good;
 always @(posedge timing_clk) launch_sample_good<=sample_good;
 (* DONT_TOUCH="true" *) reg [5:0] launch_late_bad;
 always @(posedge timing_clk) launch_late_bad<=late_bad;
 wire  dut_ready;
 (* DONT_TOUCH="true" *) reg  capture_ready;
 always @(posedge timing_clk) capture_ready<=dut_ready;
 assign ready=capture_ready;
 wire  dut_busy;
 (* DONT_TOUCH="true" *) reg  capture_busy;
 always @(posedge timing_clk) capture_busy<=dut_busy;
 assign busy=capture_busy;
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
 wire [191:0] dut_peak_power;
 (* DONT_TOUCH="true" *) reg [191:0] capture_peak_power;
 always @(posedge timing_clk) capture_peak_power<=dut_peak_power;
 assign peak_power=capture_peak_power;
 wire [275:0] dut_energy;
 (* DONT_TOUCH="true" *) reg [275:0] capture_energy;
 always @(posedge timing_clk) capture_energy<=dut_energy;
 assign energy=capture_energy;
 wire [14:0] dut_sample_count;
 (* DONT_TOUCH="true" *) reg [14:0] capture_sample_count;
 always @(posedge timing_clk) capture_sample_count<=dut_sample_count;
 assign sample_count=capture_sample_count;
 wire [5:0] dut_bad_channels;
 (* DONT_TOUCH="true" *) reg [5:0] capture_bad_channels;
 always @(posedge timing_clk) capture_bad_channels<=dut_bad_channels;
 assign bad_channels=capture_bad_channels;
 wire  dut_overflow;
 (* DONT_TOUCH="true" *) reg  capture_overflow;
 always @(posedge timing_clk) capture_overflow<=dut_overflow;
 assign overflow=capture_overflow;
 pulse_range_statistics dut(
 .clk(timing_clk),
 .rst(launch_rst),
 .start(launch_start),
 .sample_enable(launch_sample_enable),
 .finish(launch_finish),
 .result_ready(launch_result_ready),
 .pulse_id(launch_pulse_id),
 .iq_i(launch_iq_i),
 .iq_q(launch_iq_q),
 .sample_good(launch_sample_good),
 .late_bad(launch_late_bad),
 .ready(dut_ready),
 .busy(dut_busy),
 .result_valid(dut_result_valid),
 .rejected(dut_rejected),
 .result_id(dut_result_id),
 .peak_power(dut_peak_power),
 .energy(dut_energy),
 .sample_count(dut_sample_count),
 .bad_channels(dut_bad_channels),
 .overflow(dut_overflow)
 );
endmodule
