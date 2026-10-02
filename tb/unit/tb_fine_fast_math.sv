`timescale 1ns/1ps
module tb_fine_fast_math;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,req_valid=0,result_ready=0,round_nearest=0;
 reg [1:0] operation=0;reg [255:0] operand_a=0,operand_b=0;
 wire req_ready,result_valid,fault;wire [255:0] result;
 fine_fast_math dut(.*);
 reg [787:0] vectors[0:511];reg [255:0] wanted;reg bad;reg [15:0] wanted_cycles;
 integer count,i,cycles,max_cycles=0;string root;
 task automatic step;begin @(negedge clk);end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count))$fatal(1,"args");
  $readmemh({root,"/wide.hex"},vectors,0,count-1);
  repeat(3)step();rst=0;
  for(i=0;i<count;i=i+1)begin
   wait(req_ready);step();{wanted_cycles,bad,wanted,round_nearest,operation,operand_b,operand_a}=vectors[i];req_valid=1;
   step();req_valid=0;cycles=0;
   while(!result_valid)begin
    step();cycles=cycles+1;if(cycles>4600||req_ready)$fatal(1,"busy/timeout");
   end
   if(cycles>max_cycles)max_cycles=cycles;
   if(cycles!=wanted_cycles)$fatal(1,"arithmetic latency %0d/%0d",cycles,wanted_cycles);
   if(result!==wanted||fault!==bad)$fatal(1,"vector%0d op%0d result%h/%h fault%b/%b",i,operation,result,wanted,fault,bad);
   repeat(i%7+1)begin step();if(!result_valid||req_ready||result!==wanted||fault!==bad)$fatal(1,"result hold");end
   result_ready=1;step();result_ready=0;
  end
  for(i=0;i<4;i=i+1)begin
   step();operation=i;operand_a='1;operand_b=123;req_valid=1;step();req_valid=0;
   repeat(5)step();abort=1;step();abort=0;step();if(!req_ready||result_valid)$fatal(1,"abort");
  end
  operation=3;req_valid=1;step();req_valid=0;repeat(17)step();rst=1;step();rst=0;
  repeat(4)step();if(!req_ready||result_valid)$fatal(1,"reset");
  $display("PASS Fine fast unsigned256 arithmetic %0d vectors max cycles %0d; overflow/borrow/round/zero/hold/cancel",count,max_cycles);$finish;
 end
endmodule
