// 125MHz sample-domain command; GSC ticks are 2ns. All times must be 4-tick aligned.
module dds_burst_control(
 input wire clk,rst,input wire [63:0] gsc,input wire cmd_valid,
 input wire [63:0] start_gsc,input wire [31:0] pw_samples,pri_samples,pulse_count,
 input wire [47:0] initial_pinc,chirp_step,input wire reset_each_pulse,abort,
 output reg busy,accepted,rejected,output wire nco_enable,envelope,phase_reset,
 output reg [47:0] pinc,output reg done);
 reg [63:0] next_start,end_gsc,train_start; reg [31:0] remaining,pri_hold,pw_hold;
 reg [47:0] base_pinc,step_hold; reg reset_hold,first_pulse;
 wire [63:0] duration_samples=pri_samples*pulse_count;
 wire [66:0] train_end={3'd0,start_gsc}+{1'b0,duration_samples,2'b00};
 assign nco_enable=busy && gsc>=train_start && !abort;
 assign envelope=busy && gsc>=next_start && gsc<end_gsc && !abort;
 assign phase_reset=envelope && gsc==next_start && (reset_hold||first_pulse);
 always @(posedge clk) begin
  if(rst) begin busy<=0;accepted<=0;rejected<=0;done<=0;pinc<=0;next_start<=0;end_gsc<=0;train_start<=0;remaining<=0;pri_hold<=0;pw_hold<=0;base_pinc<=0;step_hold<=0;reset_hold<=0;first_pulse<=0;end
  else begin
   accepted<=0;rejected<=0;done<=0;
   if(cmd_valid) begin
    if(busy||abort||pw_samples==0||pri_samples<pw_samples||pulse_count==0||start_gsc<=gsc||start_gsc[1:0]!=gsc[1:0]|||train_end[66:64]) rejected<=1;
    else begin busy<=1;accepted<=1;train_start<=start_gsc;next_start<=start_gsc;end_gsc<=start_gsc+({32'd0,pw_samples}<<2);remaining<=pulse_count;pri_hold<=pri_samples;pw_hold<=pw_samples;base_pinc<=initial_pinc;pinc<=initial_pinc;step_hold<=chirp_step;reset_hold<=reset_each_pulse;first_pulse<=1;end
   end
   if(busy) begin
    if(envelope) pinc<=pinc+step_hold;
    // Advance after consuming the last sample, including back-to-back pulses.
    if(gsc+4>=end_gsc) begin
     if(remaining==1) begin busy<=0;done<=1;end
     else begin remaining<=remaining-1;next_start<=next_start+({32'd0,pri_hold}<<2);end_gsc<=next_start+({32'd0,pri_hold}<<2)+({32'd0,pw_hold}<<2);pinc<=base_pinc;first_pulse<=0;end
    end
    if(abort) begin busy<=0;done<=1;end
   end
  end
 end
endmodule
