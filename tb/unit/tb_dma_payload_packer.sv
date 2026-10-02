`timescale 1ns/1ps
module tb_dma_payload_packer;
 reg clk=0;always #2.5 clk=~clk;reg rst=1,abort=0;
 reg s_valid=0,s_last=0,m_ready=0;reg[127:0] s_data=0;reg[1:0] s_mask=0;
 wire s_ready,m_valid,m_last;wire[127:0] m_data;wire[15:0] m_keep;
 dma_payload_packer dut(.*);
 integer seen=0,total=0;reg active=0;reg[31:0] rng=32'h17345678;
 reg held_valid=0;reg[145:0] held;
 always @(negedge clk)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};m_ready=rng[3:0]>4;end
 always @(posedge clk)if(!rst)begin
  if(held_valid&&!abort&&{m_valid,m_data,m_keep,m_last}!==held)$fatal(1,"unstable packed output");
  held_valid=m_valid&&!m_ready;held={m_valid,m_data,m_keep,m_last};
  if(m_valid&&m_ready)begin
   if(!active||m_data[63:0]!==64'h1357000000000000+seen)$fatal(1,"packer low %0d",seen);
   seen=seen+1;
   if(m_keep==16'hffff)begin
    if(m_data[127:64]!==64'h1357000000000000+seen)$fatal(1,"packer high %0d",seen);seen=seen+1;
   end else if(m_keep!=16'h00ff)$fatal(1,"packer keep");
   if(m_last!==(seen==total))$fatal(1,"packer last");
  end
 end
 task automatic run(input integer odd,n);
 integer index,lanes;
 begin
  active=1;seen=0;total=n;index=0;
  while(index<n)begin
   @(negedge clk);
   if(index==0&&odd!=0)begin s_mask=2'b10;lanes=1;s_data={64'h1357000000000000+index,64'hdeadbeef};end
   else if(n-index==1)begin s_mask=2'b01;lanes=1;s_data={64'hdeadbeef,64'h1357000000000000+index};end
   else begin s_mask=2'b11;lanes=2;s_data={64'h1357000000000001+index,64'h1357000000000000+index};end
   s_valid=1;s_last=index+lanes==n;
   do @(posedge clk);while(!s_ready);
   index=index+lanes;
   @(negedge clk);s_valid=0;
  end
  wait(seen==total);@(negedge clk);active=0;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(integer n=1;n<80;n=n+1)begin run(0,n);run(1,n);end
  run(1,16384);
  $display("PASS DMA packer parity/odd-tail/random-stalls/fullwindow");$finish;
 end
 initial begin #5000000;$fatal(1,"timeout");end
endmodule
