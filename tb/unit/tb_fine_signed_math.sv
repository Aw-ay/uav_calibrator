`timescale 1ns/1ps
module tb_fine_signed_math;
 parameter FAST_MATH=0;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,req_valid=0,result_ready=0,round_nearest=1,negative_a,negative_b;
 reg [1:0] operation;reg [255:0] magnitude_a,magnitude_b;
 wire req_ready,result_valid,negative,fault;wire [255:0] magnitude;
 fine_signed_math #(.FAST_MATH(FAST_MATH)) dut(.*);
 reg [775:0] vectors[0:511];reg [255:0] want;reg want_sign,want_fault;
 integer n,i,t;string root;
 task automatic step;begin @(negedge clk);end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",n))$fatal(1,"args");
  $readmemh({root,"/signed.hex"},vectors,0,n-1);repeat(3)step();rst=0;
  for(i=0;i<n;i=i+1)begin
   wait(req_ready);step();{want_fault,want_sign,want,operation,negative_b,negative_a,magnitude_b,magnitude_a}=vectors[i][773:0];req_valid=1;
   step();req_valid=0;t=0;while(!result_valid)begin step();t=t+1;if(t>5000)$fatal(1,"timeout");end
   if(fault!==want_fault||(!fault&&(magnitude!==want||negative!==want_sign)))$fatal(1,"signed op %0d case%0d",operation,i);
   repeat(3)begin step();if(!result_valid||req_ready)$fatal(1,"hold");end
   result_ready=1;step();result_ready=0;
  end
  $display("PASS signed magnitude256 %0d operations",n);$finish;
 end
endmodule
