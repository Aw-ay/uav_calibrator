`timescale 1ns/1ps
module tb_native_overload_monitor;
 reg clk=0; always #4 clk=~clk;
 reg rst=1,in_valid=0; reg [511:0] iq_i=0,iq_q=0; reg [7:0] iq_valid=0,threshold_validated=0;
 reg [135:0] near_clip_threshold=0; reg [7:0] hard_overrange_event=0,hard_overrange_known=0;
 reg [63:0] gsc_base=0,beat_seq=0;
 wire out_valid; wire [63:0] out_gsc_base,out_beat_seq; wire [7:0] near_clip,missing,threshold_unknown,hard_overrange,hard_overrange_unknown; wire [23:0] near_clip_count;
 native_overload_monitor dut(.*);
 task check(input bit ok,input string msg); if(!ok)$fatal(1,"%s",msg); endtask
 initial begin
  @(posedge clk);#1;check(!out_valid,"reset output");rst=0;
  @(negedge clk);in_valid=1;gsc_base=64'h123456789abcdef0;beat_seq=64'hfedcba9876543210;
  iq_valid=8'hff;threshold_validated=8'hff;hard_overrange_known=8'hff;near_clip_threshold={8{17'd100}};
  // lane1 and lane3 are deliberately clipped; they are discarded by later D4.
  iq_i[1*64+16+:16]=16'sd100;iq_q[3*64+48+:16]=-16'sd101;
  // Both components of one complex sample still count once. Signed minimum widens to 32768.
  iq_i[4*64+:16]=-16'sd32768;iq_q[4*64+:16]=-16'sd32768;
  hard_overrange_event=8'hff;
  @(posedge clk);#1;check(out_valid&&out_gsc_base==64'h123456789abcdef0&&out_beat_seq==64'hfedcba9876543210,"registered stamps");
  check(near_clip==8'h1a,"all native lanes observed");check(near_clip_count[1*3+:3]==1&&near_clip_count[3*3+:3]==1&&near_clip_count[4*3+:3]==1,"OR count and extrema");
  check(hard_overrange==8'hff&&!hard_overrange_unknown,"all hard events");
  @(negedge clk);iq_valid=8'hfe;threshold_validated=8'hfd;near_clip_threshold[2*17+:17]=0;hard_overrange_event=8'hff;hard_overrange_known=8'h0f;gsc_base=88;beat_seq=22;
  @(posedge clk);#1;check(missing==8'h01,"missing channel");check(threshold_unknown==8'h06,"zero or unvalidated threshold unknown");check(!near_clip[1]&&!near_clip[2],"unknown is not clean clip evidence");check(hard_overrange==8'h0f&&hard_overrange_unknown==8'hf0,"known event mask");
  @(negedge clk);in_valid=0;@(posedge clk);#1;check(!out_valid,"bubble preserved");
  // Exact numeric-domain boundaries: equality crosses; its lower neighbor does not.
  @(negedge clk);in_valid=1;iq_i=0;iq_q=0;iq_valid=8'hff;threshold_validated=8'hff;
  hard_overrange_event=8'ha5;hard_overrange_known=8'hff;gsc_base=99;beat_seq=23;
  near_clip_threshold=0;
  near_clip_threshold[0*17+:17]=17'd1;iq_i[0*64+:16]=16'sd1;
  near_clip_threshold[1*17+:17]=17'd1;iq_i[1*64+:16]=16'sd0;
  near_clip_threshold[2*17+:17]=17'd32768;iq_i[2*64+:16]=-16'sd32768;
  near_clip_threshold[3*17+:17]=17'd32768;iq_i[3*64+:16]=16'sd32767;
  near_clip_threshold[4*17+:17]=17'd32769;iq_i[4*64+:16]=-16'sd32768;
  near_clip_threshold[5*17+:17]=17'd65535;iq_i[5*64+:16]=-16'sd32768;
  near_clip_threshold[6*17+:17]=17'd131071;iq_i[6*64+:16]=-16'sd32768;
  near_clip_threshold[7*17+:17]=17'd2;
  @(posedge clk);#1;check(near_clip==8'h05,"threshold endpoint equality and neighbors");
  check(near_clip_count==24'h000041,"threshold endpoint counts");
  check(threshold_unknown==8'h70,"unrepresentable thresholds unknown");
  // Reset while a populated beat is being presented must clear every output.
  @(negedge clk);rst=1;gsc_base=64'hffff;beat_seq=64'heeee;
  @(posedge clk);#1;check(!out_valid&&out_gsc_base==0&&out_beat_seq==0&&near_clip==0&&near_clip_count==0&&missing==0&&threshold_unknown==0&&hard_overrange==0&&hard_overrange_unknown==0,"busy reset clears all outputs");
  rst=0;
  $display("PASS native_overload_monitor");$finish;
 end
endmodule
