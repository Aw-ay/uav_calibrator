`timescale 1ns/1ps
module tb_replay_drain_observer;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,task_started=0,reader_retired=0,dsp_busy=0,dsp_out_valid=0,drained_ready=0;
 reg [1535:0] task_context=0;reg [7:0] reader_status=0;
 wire start_ready,start_rejected,protocol_error,drained_valid;
 wire [1535:0] drained_context;wire [7:0] drained_status;
 replay_drain_observer dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task start(input [63:0] id);begin
  if(!start_ready)$fatal(1,"observer not ready");
  task_context={24{64'h123456789abcdef0}};task_context[768+:64]=id;
  task_started=1;tick;task_started=0;
 end endtask
 task retired(input [7:0] status);begin reader_status=status;reader_retired=1;tick;reader_retired=0;end endtask
 task await_record(input [63:0] id,input [7:0] status);integer n;begin
  n=0;while(!drained_valid&&n<12)begin tick;n=n+1;end
  if(!drained_valid||drained_status!=status||drained_context[768+:64]!=id)$fatal(1,"retirement identity/status");
  if(drained_context[64+:64]!=64'h123456789abcdef0)$fatal(1,"context truncated");
 end endtask
 initial begin
  repeat(3)tick;rst=0;tick;
  start(64'hfedcba9876543210);task_context=0;
  repeat(6)begin tick;if(drained_valid)$fatal(1,"idle DSP before reader end is not done");end
  retired(0);if(drained_valid)$fatal(1,"reader token is not DSP completion");
  dsp_busy=1;repeat(6)begin tick;if(drained_valid)$fatal(1,"late DSP busy ignored");end
  dsp_busy=0;dsp_out_valid=1;repeat(3)begin tick;if(drained_valid)$fatal(1,"final DSP output lost");end
  dsp_out_valid=0;await_record(64'hfedcba9876543210,0);
  task_started=1;task_context=0;tick;if(!start_rejected)$fatal(1,"pending record overwritten");task_started=0;
  repeat(8)begin tick;if(!drained_valid||drained_context[768+:64]!=64'hfedcba9876543210)$fatal(1,"stalled context changed");end
  drained_ready=1;tick;drained_ready=0;
  // Cancellation before first RAW sample produces no normal DSP done pulse.
  start(64'h100000001);retired(10);await_record(64'h100000001,10);
  drained_ready=1;tick;drained_ready=0;
  start(64'h200000002);dsp_busy=1;retired(11);retired(12);
  if(!protocol_error)$fatal(1,"duplicate reader token not detected");
  dsp_busy=0;await_record(64'h200000002,11);
  rst=1;tick;rst=0;tick;if(drained_valid||!start_ready)$fatal(1,"reset pending record");
  retired(0);if(!protocol_error||drained_valid)$fatal(1,"orphan token fabricated completion");
  start(64'h300000003);rst=1;tick;rst=0;tick;if(!start_ready||drained_valid)$fatal(1,"active reset");
  $display("PASS replay drain observer full identity delayed DSP cancellation backpressure duplicate orphan reset");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
