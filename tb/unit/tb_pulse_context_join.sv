`timescale 1ns/1ps
module tb_pulse_context_join;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,cancel=0,context_valid=0,stats_valid=0,noise_valid=0,result_ready=0;
 reg [255:0] context_key=0,stats_key=0,noise_key=0;
 reg [1023:0] context_data=0;reg [511:0] stats_data=0;reg [255:0] noise_data=0;
 wire context_ready,stats_ready,noise_ready,result_valid,busy;
 wire [255:0] result_key;wire [1023:0] result_context;wire [511:0] result_stats;wire [255:0] result_noise;
 wire context_rejected,stats_rejected,noise_rejected,aborted;
 pulse_context_join dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 task admit(input [255:0] key);
 begin context_key=key;context_data=1024'h123456789;context_valid=1;tick();context_valid=0;end endtask
 initial begin
 tick();rst=0;
 for(integer order=0;order<2;order=order+1)begin
  admit({64'd11,64'd22,64'd33,64'd44});check(busy&&!context_ready&&!result_valid,"context acquired");
  context_data=0;context_key=0;
  // Flip each identity component separately; stale inputs are consumed and
  // explicitly rejected, never block a correct result queued behind them.
  for(integer field=0;field<4;field=field+1)begin
   stats_key={64'd11,64'd22,64'd33,64'd44}^(256'd1<<(field*64));noise_key=stats_key;
   stats_valid=1;noise_valid=1;tick();stats_valid=0;noise_valid=0;
   check(stats_rejected&&noise_rejected&&!result_valid,"stale identity rejected");
  end
  stats_key={64'd11,64'd22,64'd33,64'd44};noise_key=stats_key;
  stats_data=512'habcdef;noise_data=256'h456789;
  if(order==0)stats_valid=1;else noise_valid=1;
  tick();stats_valid=0;noise_valid=0;check(!result_valid,"partial join must wait");
  if(order==0)begin stats_valid=1;stats_data=0;end else begin noise_valid=1;noise_data=0;end
  tick();check(order==0?stats_rejected:noise_rejected,"duplicate result rejected");stats_valid=0;noise_valid=0;
  stats_data=512'habcdef;noise_data=256'h456789;
  if(order==0)noise_valid=1;else stats_valid=1;
  tick();stats_valid=0;noise_valid=0;
  check(result_valid&&result_context==1024'h123456789&&result_stats==512'habcdef&&result_noise==256'h456789,"immutable complete join");
  stats_data=0;noise_data=0;repeat(4)tick();check(result_valid&&result_stats==512'habcdef,"backpressure stability");
  context_valid=1;tick();context_valid=0;check(context_rejected,"pending context cannot be replaced");
  result_ready=1;tick();result_ready=0;check(context_ready&&!busy&&!result_valid,"consume releases context");
 end
 admit(256'd123);cancel=1;stats_valid=1;stats_key=123;tick();cancel=0;stats_valid=0;#1;
 check(aborted&&context_ready&&!result_valid,"cancel wins over incoming results");
 stats_valid=1;noise_valid=1;tick();stats_valid=0;noise_valid=0;
 check(stats_rejected&&noise_rejected&&!result_valid,"post-cancel stale arrivals rejected");
 admit(256'd999);rst=1;tick();rst=0;check(!busy&&!result_valid,"reset discards partial transaction");
 admit(256'd1234);stats_key=1234;noise_key=1234;stats_data=17;noise_data=19;stats_valid=1;noise_valid=1;
 tick();stats_valid=0;noise_valid=0;check(result_valid&&result_stats==17&&result_noise==19,"same-edge two result join");
 cancel=1;result_ready=1;tick();cancel=0;result_ready=0;#1;check(aborted&&!result_valid,"cancel completed held result");
 // New context and its results on the same edge are not an atomic bypass.
 context_key=1235;stats_key=1235;noise_key=1235;context_valid=1;stats_valid=1;noise_valid=1;
 tick();context_valid=0;stats_valid=0;noise_valid=0;check(busy&&stats_rejected&&noise_rejected&&!result_valid,"results require prior context admission");
 $display("PASS pulse context join order identity duplicate immutable backpressure cancel reset");$finish;
 end
 initial begin #10000;$fatal(1,"watchdog");end
endmodule
