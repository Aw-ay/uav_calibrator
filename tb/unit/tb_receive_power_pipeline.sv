`timescale 1ns/1ps
module tb_receive_power_pipeline;
 reg clk=0,rst=1,sample_valid=1,time_valid=1;always #4 clk=~clk;
 reg [63:0] sample_seq=0;reg [255:0] group_data=0;reg [7:0] logical_good=8'hff;
 wire power_valid;wire [63:0] power_seq;wire [191:0] power_data;wire [5:0] power_good;
 receive_power_pipeline dut(.*);
 reg [447:0] vectors[0:255];string root;integer n;
 initial begin
  if(!$value$plusargs("ROOT=%s",root))$fatal(1,"ROOT");$readmemh({root,"/power.hex"},vectors);
  repeat(3)@(negedge clk);rst=0;
  for(n=0;n<258;n=n+1)begin
   @(negedge clk);sample_seq=n;group_data=vectors[n%256][255:0];
   sample_valid=n%11!=0;time_valid=n%13!=0;logical_good=8'(n);
   @(posedge clk);#1;
   if(n>=1)begin
    if(power_seq!=n-1||power_data!==vectors[(n-1)%256][447:256]||power_valid!=((n-1)%11!=0))$fatal(1,"power arithmetic/sequence latency n=%0d",n);
    if(power_good!==((((n-1)%11!=0)&&((n-1)%13!=0))?{3'((n-1)>>4),3'(n-1)}:6'b0))$fatal(1,"power quality alignment");
   end
  end
  $display("PASS six power pipeline random signed IQ, -32768 extrema, channel order, validity, two registers");$finish;
 end
endmodule
