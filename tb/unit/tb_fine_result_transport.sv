`timescale 1ns/1ps
module tb_fine_result_transport;
 reg clk_mem=0,clk_rf=0,rst_n=0;always #2.5 clk_mem=~clk_mem;always #4 clk_rf=~clk_rf;
 reg lost_valid=0;reg in_valid=0,command_valid=0,command_pop=0;reg [1023:0] in_data=0;reg [63:0] command_token=0;
 wire command_ready,response_valid,response_ok,available_rf;wire [1151:0] response_data;
 fine_result_transport #(.ADDR_W(2)) dut(.*);
 task automatic issue(input bit pop,input [63:0] token);begin
  wait(command_ready);@(negedge clk_rf);command_valid=1;command_pop=pop;command_token=token;
  @(negedge clk_rf);command_valid=0;wait(response_valid);#1;
 end endtask
 task automatic push(input [31:0] data);begin @(negedge clk_mem);in_valid=1;in_data=data;@(negedge clk_mem);in_valid=0;end endtask
 initial begin
  repeat(4)@(negedge clk_rf);rst_n=1;repeat(5)@(negedge clk_rf);
  issue(0,0);if(!response_ok||response_data!=0||available_rf)$fatal(1,"empty peek");
  for(integer n=1;n<=6;n=n+1)push(n);
  issue(0,0);if(!response_ok||response_data[31:0]!=4||response_data[63:32]!=2||response_data[127:64]!=1||response_data[159:128]!=1||!available_rf)$fatal(1,"overflow/head");
  issue(1,2);if(response_ok||response_data[31:0]!=4)$fatal(1,"wrong token");
  issue(0,0);if(response_data[127:64]!=1)$fatal(1,"peek changed head");
  issue(1,1);if(!response_ok)$fatal(1,"pop");issue(1,1);if(response_ok)$fatal(1,"duplicate pop");
  push(7);
  for(integer n=2;n<=5;n=n+1)begin
   issue(0,0);if(response_data[127:64]!=n||response_data[159:128]!=(n==5?7:n))$fatal(1,"order/wrap");
   issue(1,n);if(!response_ok)$fatal(1,"exact pop");
  end
  repeat(5)@(negedge clk_rf);if(available_rf)$fatal(1,"level irq remained");
  @(negedge clk_mem);lost_valid=1;@(negedge clk_mem);lost_valid=0;
  issue(0,0);if(response_data[31:0]!=0||response_data[63:32]!=3)$fatal(1,"failed analysis must count as loss");
  for(integer n=0;n<4;n=n+1)push(99);
  @(negedge clk_mem);lost_valid=1;in_valid=1;
  @(negedge clk_mem);lost_valid=0;in_valid=0;
  issue(0,0);if(response_data[63:32]!=5)$fatal(1,"simultaneous queue and analysis loss");
  for(integer n=6;n<=9;n=n+1)issue(1,n);
  // Saturation and token exhaustion prohibit aliasing, while still accepting input attempts.
  dut.dropped=32'hfffffffe;dut.next_token=64'hffffffffffffffff;
  push(42);push(43);push(44);
  issue(0,0);if(response_data[127:64]!=64'hffffffffffffffff||response_data[63:32]!=32'hffffffff||response_data[31:0]!=1)$fatal(1,"exhaustion/drop saturation");
  issue(1,64'hffffffffffffffff);push(45);issue(0,0);if(response_data[31:0]!=0)$fatal(1,"token reuse");
  @(negedge clk_rf);rst_n=0;repeat(4)@(negedge clk_rf);rst_n=1;repeat(5)@(negedge clk_rf);push(77);issue(0,0);
  if(response_data[127:64]!=1||response_data[63:32]!=0)$fatal(1,"cold reset");
  push(78);push(79);push(80);
  fork
   begin issue(1,1);if(!response_ok||response_data[31:0]!=4||response_data[159:128]!=77)$fatal(1,"atomic pre-pop snapshot");end
   begin
    wait(dut.command_pending_mem&&dut.command_mem[64]);@(negedge clk_mem);in_data=81;in_valid=1;
    @(negedge clk_mem);in_valid=0;
   end
  join
  issue(0,0);if(response_data[31:0]!=4||response_data[63:32]!=0||response_data[127:64]!=2||response_data[159:128]!=78)$fatal(1,"full simultaneous pop/push credit");
  for(integer n=2;n<=5;n=n+1)begin
   issue(0,0);if(response_data[159:128]!=76+n||response_data[127:64]!=n)$fatal(1,"simultaneous wrap order");issue(1,n);
  end
  $display("PASS Fine mem/RF transport: atomic PEEK, exact POP, queue wrap, drop-on-full, IRQ level, saturated drops, token exhaustion, full simultaneous POP/PUSH");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
