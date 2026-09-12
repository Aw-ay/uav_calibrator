module tb_eight_channel;
 reg clk_rf=0; always #4 clk_rf=~clk_rf;
 reg rst=1,acquisition_enable=0,tx_permit=0,tx_fault=0;
 reg [1023:0] native_adc_data=0;
 reg [15:0] native_adc_valid=0;
 wire [15:0] native_adc_ready;
 reg [127:0] tx_i=0,tx_q=0;
 reg [7:0] tx_valid=0,tx_enable_mask=0;
 wire [127:0] rx_i,rx_q;
 wire [7:0] rx_valid,rx_quality,rx_saturated,tx_saturated;
 wire [1023:0] native_dac_data;
 wire [7:0] native_dac_valid;
 calibrator_top dut(.*);
 integer fd,rc;
 initial begin
  fd=$fopen("tb/vectors/eight_channel.txt","r");
  while(!$feof(fd)) begin
   @(negedge clk_rf);
   rc=$fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",rst,acquisition_enable,native_adc_data,native_adc_valid,tx_i,tx_q,tx_valid,tx_enable_mask,tx_permit,tx_fault);
   @(posedge clk_rf); #1;
   if(native_adc_ready!==16'hffff || native_dac_valid!==8'hff) $fatal(1,"continuous native interface violated");
   $display("DATA %h %h %h %h %h %h %h",rx_valid?rx_i:128'b0,rx_valid?rx_q:128'b0,rx_valid,rx_quality,native_dac_data,rx_saturated,tx_saturated);
  end
  $finish;
 end
endmodule
