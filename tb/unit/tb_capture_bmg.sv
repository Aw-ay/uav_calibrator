`timescale 1ns/1ps
module tb_capture_bmg;
 reg clka=0,clkb=0,ena=0,wea=0,enb=0;
 reg [13:0] addra=0;reg [12:0] addrb=0;reg [63:0] dina=0;
 wire [63:0] douta;wire [127:0] doutb;
 always #4 clka=~clka;always #2.5 clkb=~clkb;
 capture_ram_probe dut(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta),
  .clkb(clkb),.enb(enb),.web(1'b0),.addrb(addrb),.dinb(128'b0),.doutb(doutb));
 function automatic [63:0] value(input integer n);value={32'h9abc0000|n,32'h12340000|n};endfunction
 initial begin
  // Fill all rows to test address depth, not just low-address behavior.
  for(integer n=0;n<16384;n=n+1)begin @(negedge clka);ena=1;wea=1;addra=n;dina=value(n);end
  @(negedge clka);wea=0;ena=0;
  for(integer n=0;n<8192;n=n+1)begin
   @(negedge clkb);enb=1;addrb=n;
   @(posedge clkb);#0.5;
   if(doutb!=={value(2*n+1),value(2*n)})$fatal(1,"B pair mismatch addr=%0d got=%h",n,doutb);
  end
  @(negedge clkb);enb=0;
  for(integer n=16380;n<16384;n=n+1)begin
   @(negedge clka);ena=1;addra=n;
   @(posedge clka);#0.5;if(douta!==value(n))$fatal(1,"A replay mismatch %0d",n);
  end
  $display("PASS capture BMG 2025.2: full16384 A64 writes,8192 B128 reads, A replay, clocks125/200MHz");$finish;
 end
 initial begin #500000;$fatal(1,"BMG timeout");end
endmodule
