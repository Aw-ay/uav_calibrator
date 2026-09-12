`timescale 1ns/1ps
module tb_receive_frontend;
 reg clk_rf=0,rst=1,enable=1;always #4 clk_rf=~clk_rf;
 reg [1023:0] native_adc_data=0;reg [15:0] native_adc_valid=65535;wire [15:0] native_adc_ready;
 reg [63:0] native_seq=0,native_gsc=0;reg common_clock_good=1,mapping_valid=1;reg [7:0] mts_locked=255;
 reg [23:0] logical_to_physical=0;reg [135:0] near_clip_threshold=0;reg [7:0] threshold_validated=255,hard_overrange_event=0,hard_overrange_known=255;
 wire sample_valid;wire [63:0] sample_seq,sample_gsc;wire [255:0] group_data;wire [7:0] logical_good,logical_saturated,physical_good,physical_saturated;
 calibrator_receive_frontend dut(.*);
 task tick;begin @(posedge clk_rf);#1;@(negedge clk_rf);end endtask
 initial begin
  for(integer c=0;c<8;c=c+1)begin logical_to_physical[c*3+:3]=c;near_clip_threshold[c*17+:17]=30000;for(integer n=0;n<4;n=n+1)begin native_adc_data[(2*c)*64+n*16+:16]=100+c*100;native_adc_data[(2*c+1)*64+n*16+:16]=0;end end
  tick();rst=0;
  for(integer n=0;n<130;n=n+1)begin
   native_seq=n;native_gsc=1000+n*4;tick();
   if(n>=14&&(!sample_valid||sample_seq!=n-14||sample_gsc!=1000+(n-14)*4))$fatal(1,"sample timestamp mismatch");
  end
  if(logical_good!=255||native_adc_ready!=65535)$fatal(1,"steady quality/ADC always ready");
  for(integer g=0;g<4;g=g+1)if(group_data[g*64+:16]!=100+g*100||group_data[g*64+32+:16]!=500+g*100)$fatal(1,"physical mapping/real FIR data");
  native_adc_valid[0]=0;native_seq=130;native_gsc=1520;tick();if(logical_good[0]||!sample_valid)$fatal(1,"missing beat quality without stream compression");
  native_adc_valid=65535;for(integer n=131;n<195;n=n+1)begin native_seq=n;native_gsc=1000+4*n;tick();end
  if(!logical_good[0])$fatal(1,"recovery");
  logical_to_physical[3+:3]=0;#1;if(logical_good!=0)$fatal(1,"duplicate physical binding");
  $display("PASS receive frontend native FIR mapping timestamps quality missing beat");$finish;
 end
endmodule
