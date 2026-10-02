`timescale 1ns/1ps
module tb_capture_online_statistics;
 reg clk=0,rst=1,sample_valid=1;always #4 clk=~clk;
 reg [63:0] sample_seq=0;reg [255:0] group_data={4{64'h0000000a0000000a}};reg [5:0] sample_good=63;
 reg onset_valid=0;wire onset_ready;reg [127:0] onset_key=0;reg [63:0] onset_seq=0;reg [191:0] onset_noise=0;reg [13:0] onset_eop_hold=1;
 reg body_end_valid=0;reg [127:0] body_end_key=0;reg [63:0] body_end_seq=0;
 reg cancel_valid=0;reg [127:0] cancel_key=0;reg [127:0] query_key=0;wire query_valid;reg query_ready=0;
 wire [511:0] query_stats;wire [191:0] query_peaks;wire [7:0] query_error;wire idle;
 capture_online_statistics dut(
 .query_tops(),
.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);sample_seq=sample_seq+1;end endtask
 initial begin
  repeat(4)tick();rst=0;repeat(10)tick();
  for(integer s=0;s<4;s=s+1)begin
   onset_key={64'd7,64'(s+1)};onset_seq=sample_seq-1;onset_valid=1;#1;
   if(!onset_ready)$fatal(1,"four independent reservations");tick();onset_valid=0;
   body_end_key=onset_key;body_end_seq=onset_seq+1;body_end_valid=1;tick();body_end_valid=0;
  end
  if(onset_ready)$fatal(1,"full contexts may not admit");
  // Cancel one retained context before its delayed result exists.
  cancel_key={64'd7,64'd2};cancel_valid=1;tick();cancel_valid=0;
  repeat(285)tick();
  query_key={64'd8,64'd1};#1;if(query_valid)$fatal(1,"wrong epoch matched");
  query_key={64'd7,64'd2};#1;if(query_valid)$fatal(1,"canceled context retained");
  for(integer s=3;s>=0;s=s-1)if(s!=1)begin
   query_key={64'd7,64'(s+1)};#1;
   if(!query_valid||query_error!=0||query_stats[290:276]!=1||query_stats[296:291]!=0)$fatal(1,"retained identity/status");
   for(integer c=0;c<6;c=c+1)if(query_stats[c*46+:46]!=100||query_peaks[c*32+:32]!=100)$fatal(1,"retained arithmetic");
   repeat(5)tick();if(!query_valid)$fatal(1,"query backpressure lost result");
   query_ready=1;tick();query_ready=0;
  end
  if(!idle)$fatal(1,"release/cancel leaked context");
  // Duplicate live key cannot be atomically admitted, even with free slots.
  onset_key={64'd9,64'd1};onset_seq=sample_seq-1;onset_valid=1;tick();onset_valid=0;#1;
  if(onset_ready)$fatal(1,"duplicate admission");
  cancel_key=onset_key;cancel_valid=1;tick();cancel_valid=0;
  body_end_key=onset_key;body_end_seq=onset_seq+1;body_end_valid=1;tick();body_end_valid=0;
  repeat(285)tick();if(!idle)$fatal(1,"canceled active context did not drain");
  $display("PASS capture online reservations full/duplicate/backpressure exact epoch and producer cancellation");$finish;
 end
endmodule
