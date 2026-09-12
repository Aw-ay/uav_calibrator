`timescale 1ns/1ps
module tb_fault_event_retainer;
 reg clk=0,rst=1,in_valid=0,out_ready=0;reg [255:0] in_data=0;
 wire out_valid,out_saturated;wire [255:0] out_data;wire [3:0] out_occurrences;
 fault_event_retainer #(.COUNT_W(4)) dut(.*);
 always #4 clk=~clk;
 integer sent=0,received=0;reg score=1;reg [31:0] prng=32'h4321abcd;
 task step(input bit iv,ready);reg held;reg [255:0] old_data;reg [3:0] old_count;reg old_sat;begin
  @(negedge clk);in_valid=iv;out_ready=ready;
  if(iv)begin sent=sent+1;in_data={224'd0,sent[31:0]};end
  held=out_valid&&!ready;old_data=out_data;old_count=out_occurrences;old_sat=out_saturated;
  if(score&&out_valid&&ready)begin
   if(out_saturated||!out_occurrences||out_data!=={224'd0,32'(received+1)})$fatal(1,"order/count head received=%0d data=%0d",received,out_data);
   received=received+out_occurrences;if(received>sent)$fatal(1,"fabricated events");
  end
  @(posedge clk);#1;
  if(held&&(!out_valid||out_data!==old_data||out_occurrences!==old_count||out_saturated!==old_sat))$fatal(1,"blocked output changed");
  if(!out_valid&&(out_data!==0||out_occurrences!==0||out_saturated))$fatal(1,"empty outputs");
 end endtask
 task reset;begin @(negedge clk);rst=1;in_valid=0;out_ready=0;@(posedge clk);#1;if(out_valid||out_data||out_occurrences||out_saturated)$fatal(1,"reset");@(negedge clk);rst=0;sent=0;received=0;end endtask
 initial begin
  reset;
  step(1,0);step(1,0);step(1,0);step(1,1);step(1,1);step(0,1);step(0,1);
  if(sent!=received||out_valid)$fatal(1,"directed drain");
  for(integer n=0;n<2000;n=n+1)begin
   prng={prng[30:0],prng[31]^prng[21]^prng[1]^prng[0]};
   step(prng[0]||prng[4],n%8==0||prng[3]);
  end
  repeat(4)step(0,1);if(sent!=received||out_valid)$fatal(1,"random conservation");
  $display("PASS retainer random count=%0d",sent);
  reset;score=0;
  step(1,0);repeat(20)step(1,0);
  if(out_data[31:0]!=1||out_occurrences!=1||out_saturated)$fatal(1,"head saturation leakage");
  step(1,1);if(out_data[31:0]!=2||out_occurrences!=15||!out_saturated)$fatal(1,"pending saturated summary");
  step(0,1);if(out_data[31:0]!=22||out_occurrences!=1||out_saturated)$fatal(1,"arrival during promotion lost");
  step(0,1);if(out_valid)$fatal(1,"saturation drain");
  step(1,0);step(1,0);reset;score=1;step(1,1);step(0,1);if(received!=1)$fatal(1,"reset recovery");
  $display("PASS fault event retainer stable ordered conservation saturation simultaneous reset");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
