`timescale 1ns/1ps
module tb_pulse_qualification_engine;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,cancel_all=0,context_valid=0,stats_valid=0,noise_valid=0,result_ready=0;
 reg [255:0] context_key=0,stats_key=0,noise_key=0;
 reg [1023:0] context_data=0;reg [511:0] stats_data=0;reg [255:0] noise_data=0;
 wire context_ready,stats_ready,noise_ready,result_valid;
 wire [255:0] result_key;wire [5:0] qualified,pair_known,pair_pass;
 wire [47:0] reasons;wire selected_valid;wire [1:0] selected_range;
 wire context_rejected,stats_rejected,noise_rejected;wire [3:0] occupied;
 pulse_qualification_engine dut(.*);
 integer seen,index;
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string s);if(!ok)$fatal(1,"%s",s);endtask
 task configure_context(input integer id,input [5:0] order,input bit common);
 begin
  context_data=0;for(integer c=0;c<6;c=c+1)context_data[c*32+:32]=65536;
  context_data[223:192]=65536;context_data[239:224]=0;context_data[245:240]=order;
  context_data[251:246]=63;context_data[257:252]=63;
  context_data[263:258]={1'b1,common,4'b1111};
  context_key=id;context_valid=1;tick();context_valid=0;
 end endtask
 task results(input integer id);
 begin
  stats_key=id;noise_key=id;stats_data=0;noise_data=0;
  for(integer c=0;c<6;c=c+1)begin stats_data[c*46+:46]=400;noise_data[c*32+:32]=25;end
  stats_data[290:276]=4;stats_data[299:297]=7;noise_data[197:192]=63;
  // id 2 loses H_HIGH; remove it from overlap in its context too.
  if(id==2)stats_data[291]=1;
  if(id==7)stats_data[300]=1;
  if(id==8)for(integer c=0;c<6;c=c+1)noise_data[c*32+:32]=125;
  if(id==9)stats_data[290:276]=16385;
  stats_valid=1;noise_valid=1;tick();stats_valid=0;noise_valid=0;
 end endtask
 task drain_one(input integer id,input bit valid_selection,input [1:0] range_id);
 begin
  while(!result_valid)tick();check(result_key==id,"result identity");
  check(selected_valid==valid_selection,"selection validity");
  if(valid_selection)check(selected_range==range_id,"frozen rank selection");
  repeat(3)begin tick();check(result_key==id&&result_valid,"output held under backpressure");end
  result_ready=1;tick();result_ready=0;
 end endtask
 initial begin
 tick();rst=0;
 configure_context(1,6'b100100,1);configure_context(2,6'b100100,1);configure_context(3,6'b000110,1);configure_context(4,6'b100100,0);
 // Changing caller configuration after admission must not affect any context.
 context_data=0;
  results(1);results(2);results(3);results(4);
  context_key=1;context_valid=1;tick();context_valid=0;check(context_rejected,"duplicate identity still rejected after pool retires into pipeline");
 drain_one(1,1,0);drain_one(2,1,1);drain_one(3,1,2);drain_one(4,0,0);
 check(occupied==0,"context slots drained");
 configure_context(5,6'b100100,1);results(5);while(!result_valid)tick();
 cancel_all=1;tick();cancel_all=0;#1;check(!result_valid&&occupied==0,"cancel clears pipeline and pool");
 stats_key=5;noise_key=5;stats_valid=1;noise_valid=1;tick();stats_valid=0;noise_valid=0;
 check(stats_rejected&&noise_rejected,"cancelled result cannot recreate output");
  configure_context(6,6'b100100,1);results(6);rst=1;tick();rst=0;#1;check(!result_valid&&occupied==0,"reset clears in-flight qualification");
  configure_context(7,6'b100100,1);results(7);drain_one(7,0,0);
  configure_context(8,6'b100100,1);results(8);drain_one(8,0,0);
  configure_context(9,6'b100100,1);results(9);drain_one(9,0,0);
 $display("PASS qualification engine actual pool noise linearity selection frozen config backpressure cancel reset");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule

