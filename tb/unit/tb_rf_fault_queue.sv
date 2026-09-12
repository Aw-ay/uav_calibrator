`timescale 1ns/1ps
module tb_rf_fault_queue;
 reg clk=0,rst=1,fault_latched=0,time_valid=1,config_valid=1,pop_valid=0;
 reg [63:0] gsc=100,pop_token=0;reg [31:0] config_id=7;reg [2:0] rf_state=3;
 reg [9:0] normalized_inputs=10'h3ab;reg [5:0] logical_outputs=6'h28;
 wire [31:0] count,dropped;wire [63:0] head_token;wire [255:0] head_data;wire pop_ok;
 rf_fault_queue #(.ADDR_W(1)) dut(.*);
 always #4 clk=~clk;
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task rise;begin fault_latched=0;tick;fault_latched=1;tick;end endtask
 initial begin
  tick;rst=0;tick;if(count||head_data||head_token)$fatal(1,"reset");
  rise;if(count!=1||head_token!=1||head_data!=={64'd100,32'h28,32'h3ab,32'd3,32'd7,32'd3,32'h30001})$fatal(1,"snapshot");
  gsc=200;config_id=9;repeat(8)tick;if(count!=1||head_data[255:192]!=100)$fatal(1,"held fault floods or changes history");
  rise;if(count!=2)$fatal(1,"reassert");rise;if(count!=2||dropped!=1)$fatal(1,"full drop");
  pop_valid=1;pop_token=99;tick;if(count!=2)$fatal(1,"wrong token");
  pop_token=head_token;fault_latched=0;tick;pop_valid=0;
  rise;if(count!=2||head_token!=2)$fatal(1,"wrap indices");
  fault_latched=0;tick;pop_valid=1;pop_token=head_token;fault_latched=1;tick;pop_valid=0;
  if(count!=2||head_token!=3||dropped!=1)$fatal(1,"full simultaneous pop/push");
  repeat(2)begin pop_valid=1;pop_token=head_token;tick;end pop_valid=0;
  if(count||head_data||head_token)$fatal(1,"empty");
  time_valid=0;config_valid=0;rise;if(head_data[255:192]||head_data[95:32])$fatal(1,"invalid time/config");
  pop_valid=1;pop_token=head_token;tick;pop_valid=0;
  dut.next_token=64'hffffffffffffffff;rise;if(head_token!=64'hffffffffffffffff)$fatal(1,"last token");
  pop_valid=1;pop_token=head_token;tick;pop_valid=0;rise;if(count||dropped!=2)$fatal(1,"token wrapped");
  dut.dropped=32'hffffffff;rise;if(dropped!=32'hffffffff)$fatal(1,"drops overflow");
  rst=1;tick;rst=0;tick;if(count!=1||head_token!=1)$fatal(1,"first high after reset");
  $display("PASS RF fault queue edge context full token reset invalid timestamps");$finish;
 end
 initial begin #10000;$fatal(1,"timeout");end
endmodule
