`timescale 1ns/1ps
module tb_fault_event_encoder;
 reg [255:0] snapshot;reg [31:0] occurrences;reg saturated;wire [511:0] event_data;
 fault_event_encoder dut(.*);
 initial begin
  snapshot=256'h0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
  occurrences=1;saturated=0;#1;
  if(event_data!=={128'd0,snapshot,32'd0,32'd1,32'd0,32'h40001})$fatal(1,"normal layout");
  occurrences=32'hffffffff;#1;if(event_data!=={128'd0,snapshot,32'd0,32'hffffffff,32'd0,32'h40001})$fatal(1,"exact max");
  saturated=1;#1;if(event_data!=={128'd0,snapshot,32'd0,32'hffffffff,32'd1,32'h40001})$fatal(1,"saturated layout");
  $display("PASS fault event encoder layout reserved saturation");$finish;
 end
endmodule
