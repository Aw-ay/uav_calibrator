// Timing fixture only; adds launch/capture cycles, not a production wrapper.
module timing_noise_window_energy(
 input wire timing_clk,
 input wire [191:0] noise_power,
 input wire [5:0] noise_known,
 input wire [14:0] sample_count,
 output wire [275:0] noise_energy,
 output wire [5:0] energy_known
);
 (* DONT_TOUCH="true" *) reg [191:0] launch_noise_power;
 always @(posedge timing_clk) launch_noise_power<=noise_power;
 (* DONT_TOUCH="true" *) reg [5:0] launch_noise_known;
 always @(posedge timing_clk) launch_noise_known<=noise_known;
 (* DONT_TOUCH="true" *) reg [14:0] launch_sample_count;
 always @(posedge timing_clk) launch_sample_count<=sample_count;
 wire [275:0] dut_noise_energy;
 (* DONT_TOUCH="true" *) reg [275:0] capture_noise_energy;
 always @(posedge timing_clk) capture_noise_energy<=dut_noise_energy;
 assign noise_energy=capture_noise_energy;
 wire [5:0] dut_energy_known;
 (* DONT_TOUCH="true" *) reg [5:0] capture_energy_known;
 always @(posedge timing_clk) capture_energy_known<=dut_energy_known;
 assign energy_known=capture_energy_known;
 noise_window_energy dut(
 .noise_power(launch_noise_power),
 .noise_known(launch_noise_known),
 .sample_count(launch_sample_count),
 .noise_energy(dut_noise_energy),
 .energy_known(dut_energy_known)
 );
endmodule
