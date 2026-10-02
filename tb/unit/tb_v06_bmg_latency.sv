`timescale 1ns/1ps
module tb_v06_bmg_latency;
 reg clka=0,clkb=0; always #4 clka=~clka; always #2.5 clkb=~clkb;
 reg ena=0,enb=0,wea=0;reg[13:0] addra=0;reg[12:0] addrb=0;
 reg[63:0] dina=0;wire[63:0] douta;wire[127:0] doutb;
 capture_ram_probe dut(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta),
 .clkb(clkb),.enb(enb),.web(1'b0),.addrb(addrb),.dinb(128'b0),.doutb(doutb));
 integer i;
 initial begin
  for(i=0;i<128;i=i+1)begin
   @(negedge clka);ena=1;wea=1;addra=i;dina=64'h1234000000000000+i;
  end
  @(negedge clka);wea=0;ena=0;
  for(i=0;i<128;i=i+1)begin
   @(negedge clka);ena=1;addra=i;
   @(posedge clka);#1;
   if(douta!==64'h1234000000000000+i)$fatal(1,"A latency/data at %0d",i);
  end
  @(negedge clka);ena=0;
  for(i=0;i<64;i=i+1)begin
   @(negedge clkb);enb=1;addrb=i;
   @(posedge clkb);#1;
   if(doutb[63:0]!==64'h1234000000000000+2*i || doutb[127:64]!==64'h1234000000000001+2*i)
    $fatal(1,"B latency/data at %0d: %h",i,doutb);
  end
  @(negedge clkb);enb=0;
  repeat(4)@(posedge clkb);
  $display("PASS actual capture_ram_probe A_READ_LATENCY=1 B_READ_LATENCY=1 continuous_B_words=64; registered consumer samples response at following edge");
  $finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
