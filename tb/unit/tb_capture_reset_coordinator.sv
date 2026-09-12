`timescale 1ns/1ps
module tb_capture_reset_coordinator;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,reset_request=0,producers_idle=1,qualification_idle=1,upload_idle=1,replay_idle=1;
 reg [63:0] owner_epoch=9;
 wire owner_reset_request,block_new_work,busy,done;
 capture_reset_coordinator dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 initial begin
  tick();rst=0;tick();if(busy||block_new_work||owner_reset_request)$fatal(1,"idle");
  reset_request=1;producers_idle=0;#1;if(!block_new_work||owner_reset_request)$fatal(1,"immediate block");
  tick();reset_request=0;repeat(3)tick();if(!busy||owner_reset_request)$fatal(1,"latch pulse");
  producers_idle=1;qualification_idle=0;repeat(3)tick();if(owner_reset_request)$fatal(1,"qualification busy");
  qualification_idle=1;upload_idle=0;repeat(3)tick();if(owner_reset_request)$fatal(1,"upload busy");
  upload_idle=1;replay_idle=0;repeat(3)tick();if(owner_reset_request)$fatal(1,"replay busy");
  replay_idle=1;tick();if(owner_reset_request)$fatal(1,"one idle cycle insufficient");
  upload_idle=0;tick();upload_idle=1;tick();if(owner_reset_request)$fatal(1,"idle proof restarts");
  tick();if(!owner_reset_request||done)$fatal(1,"request owner after stable drain");
  repeat(3)tick();if(done||!busy)$fatal(1,"wait for owner acknowledgement");
  owner_epoch=10;tick();if(!done)$fatal(1,"epoch acknowledgement");
  repeat(2)tick();if(done||busy||block_new_work)$fatal(1,"pulse request completes");
  reset_request=1;repeat(4)tick();owner_epoch=11;tick();if(!done)$fatal(1,"second reset");
  repeat(5)tick();if(done||!owner_reset_request||!busy)$fatal(1,"held request single completion");
  reset_request=0;repeat(2)tick();if(busy)$fatal(1,"release held request");
  reset_request=1;producers_idle=0;tick();rst=1;tick();rst=0;reset_request=0;tick();if(busy)$fatal(1,"hard reset local state");
  $display("PASS capture reset coordinator stable drain owner acknowledgement pulse held reset");$finish;
 end
 initial begin #10000;$fatal(1,"watchdog");end
endmodule
