`timescale 1ns/1ps
module tb_fine_edge_solver;
 parameter FAST_MATH=0;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,req_valid=0,result_ready=0,rising;
 reg [255:0] power_window;reg [3:0] point_count;reg [2:0] bracket_offset;
 reg [14:0] bracket_index;reg [31:0] threshold,noise;
 wire req_ready,result_valid,edge_valid;wire [15:0] quality;
 wire [31:0] index_q16,two_q16,fit_q16;wire [63:0] variance_two_q32,variance_fit_q32;
 fine_edge_solver #(.FAST_MATH(FAST_MATH)) dut(.*);
 reg [615:0] vectors[0:511];reg [240:0] wanted,actual;reg [31:0] wanted_cycles;
 integer count,i,cycles,max_cycles=0;string root;
 task automatic step;begin @(negedge clk);end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count))$fatal(1,"args");
  $readmemh({root,"/edge.hex"},vectors,0,count-1);repeat(3)step();rst=0;
  for(i=0;i<count;i=i+1)begin
   wait(req_ready);step();{wanted_cycles,wanted,rising,noise,threshold,bracket_index,bracket_offset,point_count,power_window}=vectors[i];req_valid=1;
   step();req_valid=0;cycles=0;
   while(!result_valid)begin step();cycles=cycles+1;if(cycles>150000||req_ready)$fatal(1,"solver timeout");end
   if(cycles>max_cycles)max_cycles=cycles;
   if(!FAST_MATH&&cycles!=wanted_cycles)$fatal(1,"edge%0d cycles %0d/%0d",i,cycles,wanted_cycles);
   actual={quality,edge_valid,variance_fit_q32,variance_two_q32,fit_q16,two_q16,index_q16};
   if(actual!==wanted)$fatal(1,"edge%0d got%h wanted%h pc%0d sy%0d sx%0d sxx%0d sxy%0d D%0d slope%0d intercept%0d num%0d",i,actual,wanted,dut.pc,dut.sy,dut.sx,dut.sxx,dut.sxy,dut.denominator,dut.slope,dut.intercept,dut.numerator);
   repeat(i%5+1)begin step();if(!result_valid||req_ready||actual!=={quality,edge_valid,variance_fit_q32,variance_two_q32,fit_q16,two_q16,index_q16})$fatal(1,"held edge");end
   result_ready=1;step();result_ready=0;
  end
  // Abort in front-end and several microcode/long-arithmetic phases, then retry.
  for(i=0;i<6;i=i+1)begin
   step();{wanted_cycles,wanted,rising,noise,threshold,bracket_index,bracket_offset,point_count,power_window}=vectors[0];req_valid=1;
   step();req_valid=0;
   case(i)
    0:repeat(3)step();
    1:wait(dut.state==10);
    2:wait(dut.state==19&&dut.op==2);
    3:wait(dut.state==19&&dut.op==3);
    4:wait(dut.state==19&&dut.op==3);
    5:wait(result_valid);
   endcase
   step();abort=1;step();abort=0;
   repeat(3)step();if(!req_ready||result_valid)$fatal(1,"cancelled edge published");
  end
  step();{wanted_cycles,wanted,rising,noise,threshold,bracket_index,bracket_offset,point_count,power_window}=vectors[0];req_valid=1;
  step();req_valid=0;wait(dut.state==19);step();rst=1;step();rst=0;
  repeat(4)step();if(!req_ready||result_valid)$fatal(1,"cold reset");
  $display("PASS Fine complete candidate solver %0d exact vectors max cycles %0d; roots/variance/fusion/invalid/cancel",count,max_cycles);$finish;
 end
 initial begin #200000000;$fatal(1,"global solver timeout");end
endmodule
