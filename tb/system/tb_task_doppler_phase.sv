`timescale 1ns/1ps
module tb_task_doppler_phase;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,load=0,cancel=0;reg [63:0] gsc=0,reference_gsc=0,offset_ticks=0;
 reg [47:0] step=0,initial_phase=0;
 wire valid;wire signed [17:0] phase_i,phase_q;wire [63:0] phase_gsc;
 task_doppler_phase dut(.*);
 always @(posedge clk)if(!rst)gsc<=gsc+4;
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check_phase;
 reg [47:0] expected; real angle;integer ci,cq;
 begin
  if(valid)begin
   if(phase_gsc!=gsc+offset_ticks)$fatal(1,"phase timestamp mismatch");
   expected=(phase_gsc-reference_gsc)*step+initial_phase;
   // Convert unsigned top32 correctly, including negative Doppler wrap.
   angle=6.283185307179586*(expected[47:16]*1.0)/4294967296.0;
   ci=$rtoi(65536*$cos(angle));cq=$rtoi(65536*$sin(angle));
   if($signed(phase_i)-ci>103||ci-$signed(phase_i)>103||$signed(phase_q)-cq>103||cq-$signed(phase_q)>103)
    $fatal(1,"phasor expected=%0d,%0d actual=%0d,%0d",ci,cq,phase_i,phase_q);
  end
 end endtask
 task run(input [47:0] s,input [47:0] p);
 begin
  step=s;initial_phase=p;reference_gsc=gsc+100;offset_ticks=168;load=1;tick();load=0;
  repeat(8)tick();if(!valid)$fatal(1,"load never produces phase");
  repeat(40)begin if(!valid)$fatal(1,"unexpected phase gap");check_phase();tick();end
  cancel=1;tick();if(valid)$fatal(1,"cancel phase");cancel=0;tick();
 end endtask
 initial begin tick();rst=0;run(0,0);run(48'h010000000000,48'h400000000000);
  run(48'hff0000000000,48'hc00000000000);
  gsc=64'h1234000000000000;run(48'h000123456789,48'h987654321012);
  $display("PASS task Doppler GSC phase");$finish;end
 initial begin #10000;$fatal(1,"timeout");end
endmodule
