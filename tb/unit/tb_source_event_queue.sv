`timescale 1ns/1ps
module tb_source_event_queue;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,accept_valid=0,dds_done=0,awg_done=0,drained=0,time_valid=1,pop_valid=0;
 reg [31:0] accept_source=1,command_sequence=77,config_id=7,cancel_reason=0;
 reg [63:0] gsc=100,pop_token=0;wire [31:0] count,dropped;wire [63:0] head_token;wire [319:0] head_data;wire pop_ok;
 source_event_queue #(.ADDR_W(1)) dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task accept(input [31:0] src,seq);begin accept_source=src;command_sequence=seq;accept_valid=1;tick();accept_valid=0;end endtask
 task finish_source;begin dds_done=1;awg_done=1;tick();dds_done=0;awg_done=0;drained=1;gsc=gsc+20;tick();drained=0;end endtask
 initial begin
  tick();rst=0;accept(1,77);awg_done=1;drained=1;tick();awg_done=0;drained=0;
  if(count!==0)$fatal(1,"wrong-source done retired observation");gsc=120;dds_done=1;tick();dds_done=0;
  repeat(3)tick();if(count!==0)$fatal(1,"done before drain published early");
  gsc=140;drained=1;tick();drained=0;
  if(count!==1||head_token!==1||head_data!=={64'd140,64'd100,32'd1,32'd7,32'd77,32'd0,32'd1,32'h20001})$fatal(1,"normal frozen record");
  command_sequence=999;config_id=999;tick();if(head_data[127:96]!==77)$fatal(1,"identity changed");
  gsc=200;accept(2,88);cancel_reason=1;tick();cancel_reason=2;tick();cancel_reason=0;finish_source();
  if(count!==2)$fatal(1,"cancel not queued");
  accept(1,99);finish_source();if(count!==2||dropped!==1)$fatal(1,"full drop");
  pop_valid=1;pop_token=9;tick();if(count!==2)$fatal(1,"wrong pop");
  pop_token=1;tick();pop_valid=0;if(head_token!==2||head_data[95:64]!==1||head_data[127:96]!==88)$fatal(1,"cancel reason identity");
  // Fill and replace at full occupancy on one cycle.
  accept(1,100);finish_source();accept(2,101);awg_done=1;tick();awg_done=0;drained=1;pop_valid=1;pop_token=2;tick();pop_valid=0;drained=0;
  if(count!==2||dropped!==1||head_token!==3)$fatal(1,"full simultaneous pop push");
  pop_valid=1;pop_token=3;tick();pop_token=4;tick();pop_valid=0;
  if(count!==0||head_data!==0||head_token!==0)$fatal(1,"empty");
  time_valid=0;accept(1,102);time_valid=1;finish_source();
  if(head_data[319:160]!==0)$fatal(1,"invalid observation time");
  rst=1;tick();if(count!==0||dropped!==0)$fatal(1,"hard reset");
  rst=0;gsc=64'hfffffffffffffffc;accept(1,103);finish_source();
  if(head_data[319:160]!==0)$fatal(1,"GSC wrap accepted");
  pop_valid=1;pop_token=1;tick();pop_valid=0;
  // Deposit a reachable boundary state to exercise 64-bit token exhaustion.
  dut.next_token=64'hffffffffffffffff;gsc=300;accept(2,104);cancel_reason=3;tick();cancel_reason=0;finish_source();
  if(head_token!==64'hffffffffffffffff||head_data[95:64]!==3)$fatal(1,"last token or MUTE reason");
  pop_valid=1;pop_token=head_token;tick();pop_valid=0;accept(1,105);finish_source();
  if(count!==0||dropped!==1)$fatal(1,"token exhaustion wrapped");
  rst=1;tick();rst=0;accept(1,106);accept(2,107);finish_source();
  if(dropped!==1||head_data[127:96]!==106)$fatal(1,"overlap destroyed identity");
  $display("PASS source event queue identity done drain cancellation full token invalid time reset");$finish;
 end
 initial begin #10000;$fatal(1,"timeout");end
endmodule
