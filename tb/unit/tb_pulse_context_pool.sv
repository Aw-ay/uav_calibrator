`timescale 1ns/1ps
module tb_pulse_context_pool;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,cancel_all=0,context_valid=0,stats_valid=0,noise_valid=0,result_ready=0;
 reg [255:0] context_key=0,stats_key=0,noise_key=0;
 reg [1023:0] context_data=0;reg [511:0] stats_data=0;reg [255:0] noise_data=0;
 wire context_ready,stats_ready,noise_ready,result_valid;
 wire [255:0] result_key,result_noise;wire [1023:0] result_context;wire [511:0] result_stats;
 wire context_rejected,stats_rejected,noise_rejected;wire [3:0] occupied;
 integer seen,index;
 pulse_context_pool dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string s);if(!ok)$fatal(1,"%s",s);endtask
 task put(input integer n);begin context_key=n;context_data=100+n;context_valid=1;tick();context_valid=0;end endtask
 task results(input integer n);begin stats_key=n;noise_key=n;stats_data=200+n;noise_data=300+n;stats_valid=1;noise_valid=1;tick();stats_valid=0;noise_valid=0;end endtask
 initial begin
 tick();rst=0;for(integer n=1;n<=4;n=n+1)put(n);
 check(occupied==15&&!context_ready,"all slots used");put(5);check(context_rejected&&occupied==15,"full rejects without overwrite");
 results(4);tick();check(result_valid&&result_key==4,"completed slot selected");
 results(1);results(3);results(2);check(result_valid&&result_key==4,"stalled output cannot switch to newly ready slot");
 check(result_context==104&&result_stats==204&&result_noise==304,"joined payload identity");
 stats_key=4;stats_valid=1;stats_data=0;tick();stats_valid=0;check(stats_rejected&&result_stats==204,"duplicate cannot overwrite");
 result_ready=1;tick();result_ready=0;tick();check(result_valid&&result_key==1,"round robin wraps");
 put(5);check(!context_rejected,"freed slot reusable");
 results(4);check(stats_rejected&&noise_rejected,"old result rejected after reuse");
 for(integer n=1;n<=3;n=n+1)begin
  check(result_valid&&result_key==n,"fair drain order");result_ready=1;tick();result_ready=0;tick();
 end
 results(5);tick();check(result_valid&&result_key==5,"new generation payload joins");
 // Duplicate live key rejected even with free slots.
 put(5);check(context_rejected,"duplicate live identity");
 cancel_all=1;tick();cancel_all=0;#1;check(occupied==0&&!result_valid,"cancel clears all slots and output lock");
 results(5);check(stats_rejected&&noise_rejected,"post cancel stale arrivals");
 put(6);rst=1;tick();rst=0;#1;check(occupied==0&&!result_valid,"reset ownership");
 for(integer batch=0;batch<12;batch=batch+1)begin
  for(integer n=1;n<=4;n=n+1)put(100+batch*4+n);
  // Independent result streams target different slots on the same edge.
  for(integer n=1;n<=4;n=n+1)begin
   stats_key=100+batch*4+n;noise_key=100+batch*4+5-n;
   stats_data=stats_key+200;noise_data=noise_key+300;stats_valid=1;noise_valid=1;tick();
  end
  stats_valid=0;noise_valid=0;tick();seen=0;
  for(integer n=0;n<4;n=n+1)begin
   check(result_valid,"all interleaved contexts complete");index=result_key-(100+batch*4+1);
   check(index>=0&&index<4&&!seen[index],"no duplicate or foreign result");seen=seen|(1<<index);
   check(result_context==result_key+100&&result_stats==result_key+200&&result_noise==result_key+300,"cross-slot payload identity");
   result_ready=1;tick();result_ready=0;tick();
  end
  check(seen==15&&occupied==0,"complete pool reuse cycle");
 end
 $display("PASS pulse context pool full interleaved stable fair reuse stale duplicate cancel reset, 48 repeated contexts");$finish;
 end
 initial begin #10000;$fatal(1,"watchdog");end
endmodule
