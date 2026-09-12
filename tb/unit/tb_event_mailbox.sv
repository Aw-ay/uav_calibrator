`timescale 1ns/1ps
module tb_event_mailbox;
 reg src_clk=0,ctrl_clk=0,rst_n=0;
 always #4 src_clk=~src_clk;always #5 ctrl_clk=~ctrl_clk;
 reg event_valid=0;reg [511:0] event_data=0;
 reg latch_head=0,pop=0;reg [3:0] word_index=0;
 wire event_ready,latched_valid,command_rejected;wire [31:0] word_data,dropped_events,event_count;
 event_mailbox #(.ADDR_W(1)) dut(.*);
 task tick;begin @(posedge ctrl_clk);#1;@(negedge ctrl_clk);end endtask
 task send(input integer id);begin
  @(negedge src_clk);while(!event_ready)@(negedge src_clk);
  for(integer w=0;w<16;w=w+1)event_data[w*32+:32]=id*100+w;
  event_valid=1;@(negedge src_clk);event_valid=0;
 end endtask
 task read_record(input integer id);begin
  while(event_count==0)tick();latch_head=1;tick();latch_head=0;
  if(!latched_valid)$fatal(1,"latch empty");
  for(integer w=15;w>=0;w=w-1)begin word_index=w;#1;if(word_data!=id*100+w)$fatal(1,"word/order");tick();end
  pop=1;tick();pop=0;if(latched_valid)$fatal(1,"pop invalidates snapshot");
 end endtask
 initial begin
  repeat(4)tick();rst_n=1;repeat(4)tick();
  pop=1;tick();pop=0;if(!command_rejected)$fatal(1,"pop without latch");
  send(1);send(2);send(3);repeat(15)tick();
  if(event_count!=2||event_ready)$fatal(1,"bounded queue plus mailbox");
  @(negedge src_clk);event_valid=1;@(negedge src_clk);event_valid=0;
  if(dropped_events!=1)$fatal(1,"source overrun accounted");
  read_record(1);read_record(2);read_record(3);repeat(15)tick();
  if(event_count!=0)$fatal(1,"drained");
  for(integer n=4;n<16;n=n+1)begin send(n);read_record(n);end
  send(20);repeat(10)tick();latch_head=1;tick();latch_head=0;
  rst_n=0;tick();rst_n=1;repeat(5)tick();
  if(event_count||latched_valid||dropped_events)$fatal(1,"coordinated reset");
  $display("PASS event mailbox CDC queue snapshot words pop full drop wrap reset");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
