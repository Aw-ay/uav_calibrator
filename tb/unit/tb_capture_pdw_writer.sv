`timescale 1ns/1ps
module tb_capture_pdw_writer;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,in_valid=0,event_ready=0;
 reg [63:0] pulse_id=7,owner_epoch=8,toa_gsc=1000,energy_sum=999;
 reg [31:0] config_id=9,width_ticks=28,peak_power=100,flags=31,selected_range=1;
 wire in_ready,event_valid,rejected;wire [511:0] event_data;reg [511:0] held;
 capture_pdw_writer dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 initial begin
  tick();rst=0;in_valid=1;tick();in_valid=0;
  if(!event_valid||event_data!={32'd1,64'd999,32'd100,32'd28,64'd1000,32'd9,64'd8,64'd7,32'd31,32'h00010001})$fatal(1,"schema");
  held=event_data;pulse_id=88;repeat(3)tick();if(event_data!=held||in_ready)$fatal(1,"held event");
  in_valid=1;tick();in_valid=0;if(!rejected||event_data!=held)$fatal(1,"reject overwrite");
  event_ready=1;tick();event_ready=0;flags=0;in_valid=1;tick();in_valid=0;
  if(event_data[447:416]!=32'hffffffff||event_data[415:224]!=0||event_data[511:448]!=0||event_data[31:0]!=32'h00010001)$fatal(1,"unknown fields zero/sentinel");
  rst=1;tick();if(event_valid)$fatal(1,"reset");
  $display("PASS capture PDW schema immutable ownership unknown fields");$finish;
 end
endmodule
