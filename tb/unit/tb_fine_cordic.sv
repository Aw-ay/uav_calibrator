`timescale 1ns/1ps
module tb_fine_cordic;
 reg clk=0,rst=1;always #2.5 clk=~clk;
 reg request_valid=0;wire request_ready;reg signed [47:0] x_in=0,y_in=0;
 wire result_valid;reg result_ready=0;wire signed [31:0] phase_q31;wire zero_vector,busy;
 fine_cordic dut(.*);
 reg [128:0] vectors[0:1006];string root;integer count,n,cycles;
 task tick;begin @(posedge clk);#0.1;@(negedge clk);end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count))$fatal(1,"vectors required");
  $readmemh({root,"/cordic.hex"},vectors,0,count-1);
  repeat(3)tick();rst=0;tick();
  // Cold reset cancels an in-flight calculation; no ghost result may emerge.
  x_in=123;y_in=-457;request_valid=1;tick();request_valid=0;repeat(9)tick();rst=1;tick();rst=0;repeat(40)tick();
  if(result_valid||busy||!request_ready)$fatal(1,"reset did not clear busy result");
  for(n=0;n<count;n=n+1)begin
   x_in=vectors[n][47:0];y_in=vectors[n][95:48];request_valid=1;
   if(!request_ready)$fatal(1,"not ready before job");tick();request_valid=0;cycles=0;
   while(!result_valid)begin tick();cycles=cycles+1;if(cycles>40)$fatal(1,"CORDIC timeout");end
   if(cycles!=(vectors[n][128]?0:33))$fatal(1,"phase latency mismatch cycles=%0d",cycles);
   if(phase_q31!==vectors[n][127:96]||zero_vector!==vectors[n][128])$fatal(1,"phase mismatch n=%0d got=%0d expected=%0d zero=%b",n,phase_q31,$signed(vectors[n][127:96]),zero_vector);
   repeat(n%5+1)begin
    if(!result_valid||!busy||request_ready||phase_q31!==vectors[n][127:96])$fatal(1,"held output changed");tick();
   end
   result_ready=1;tick();result_ready=0;
  end
  $display("PASS Fine CORDIC exact fixed-point vectors=%0d quadrants/extrema/zero/reset/backpressure",count);$finish;
 end
endmodule
