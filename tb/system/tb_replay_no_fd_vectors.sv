`timescale 1ns/1ps
module tb_replay_no_fd_vectors;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,profile_commit=0,hard_fault=0;
 reg [1:0] shadow_cal_valid=3;reg [63:0] shadow_dc;
 reg [71:0] shadow_gain;reg [143:0] shadow_matrix;
 reg [7:0] shadow_fd_phase=255;reg [31:0] shadow_fd_version=32'hbad0cafe;
 reg phase_valid=1;reg signed [17:0] phase_i,phase_q;
 reg in_valid=0,in_last=0;reg [63:0] in_hv;
 wire profile_ready,profile_accepted,profile_rejected,source_ready,busy,done,cancelled;
 wire [63:0] out_hv;wire out_valid,out_qualified,arithmetic_saturated;wire [31:0] table_version;
 replay_processing_chain dut(.*);
 reg [63:0] expected,expect_pipe[0:2];reg [2:0] valid_pipe=0;
 integer f,r,received=0,clips,job_clips;reg [1023:0] path;
 always @(posedge clk)begin
  if(rst) valid_pipe=0;
  else begin
   valid_pipe={valid_pipe[1:0],in_valid&&source_ready};
   expect_pipe[2]=expect_pipe[1];expect_pipe[1]=expect_pipe[0];expect_pipe[0]=expected;
   #1;
   if(out_valid!==valid_pipe[2])$fatal(1,"RXCAL1+Target2 exact valid latency");
   if(out_valid)begin
    if(!out_qualified||out_hv!==expect_pipe[2])$fatal(1,"golden mismatch %d got %h expected %h",received,out_hv,expect_pipe[2]);
    received=received+1;
   end
  end
 end
 task tick;begin @(posedge clk);#2;@(negedge clk);end endtask
 initial begin
  if(!$value$plusargs("VECTORS=%s",path))$fatal(1,"vectors");f=$fopen(path,"r");
  tick();rst=0;
  for(integer j=0;j<20;j=j+1)begin
   r=$fscanf(f,"%h %h %h %h %h\n",shadow_dc,shadow_gain,shadow_matrix,phase_i,phase_q);
   if(r!=5)$fatal(1,"profile file");
   profile_commit=1;tick();profile_commit=0;
   if(!profile_accepted||table_version!=0)$fatal(1,"profile independent of retired FD fields");
   job_clips=0;
   for(integer n=0;n<32;n=n+1)begin
    in_valid=0;repeat((n*7+j)%4)tick();
    r=$fscanf(f,"%h %h %d\n",in_hv,expected,clips);if(r!=3)$fatal(1,"sample file");
    job_clips=job_clips|clips;in_valid=1;in_last=n==31;tick();
   end
   in_valid=0;in_last=0;
   while(!done)tick();
   if(received!=(j+1)*32||arithmetic_saturated!==1'(job_clips))$fatal(1,"count/saturation");
  end
  $display("PASS no-FD640 fixed-point vectors: extrema, rounding, saturation, profiles, gaps, exact3-stage latency");$finish;
 end
 initial begin #200000;$fatal(1,"watchdog");end
endmodule
