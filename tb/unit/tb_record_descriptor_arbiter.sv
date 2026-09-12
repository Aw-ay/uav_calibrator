`timescale 1ns/1ps
module tb_record_descriptor_arbiter;
 reg clk=0,rst=1;
 always #4 clk=~clk;
 reg [3:0] sv=0;
 wire [3:0] sr;
 reg [127:0] data_in=0;
 wire [31:0] data_out;
 wire valid_out;
 wire [1:0] group_out;
 reg ready_out=0,done=0;
 wire busy;
 record_descriptor_arbiter #(.WIDTH(32)) dut(.clk(clk),.rst(rst),.s_valid(sv),.s_ready(sr),.s_data(data_in),.m_valid(valid_out),.m_ready(ready_out),.m_data(data_out),.m_group(group_out),.record_done(done),.busy(busy));
 integer next_group=0,accepted=0,remaining=0,rounds=0;
 reg pending=0,stall=0;
 reg [33:0] held;
 always @(posedge clk) if(rst)begin stall=0;pending=0;end else begin
  if(stall&&(!valid_out||{group_out,data_out}!==held))$fatal(1,"descriptor changed under backpressure");
  if(valid_out&&ready_out)begin
   if(pending)$fatal(1,"new record before completion");
   if(group_out!==next_group[1:0])$fatal(1,"round robin order");
   if(sr!==(4'b1<<group_out))$fatal(1,"source acceptance must be onehot");
   if(data_out!==data_in[group_out*32+:32])$fatal(1,"descriptor payload changed");
   next_group=(next_group+1)%4;accepted=accepted+1;pending=1;
  end else if(sr!=0)$fatal(1,"source accepted without descriptor handshake");
  if(done)pending=0;
  stall=valid_out&&!ready_out;held={group_out,data_out};
 end
 initial begin
  repeat(3)@(negedge clk);rst=0;
  // Select group 2 while alone. New higher-priority arrivals during a stall
  // must not alter the previously selected descriptor.
  sv=4'b0100;data_in={32'h300,32'h200,32'h100,32'h000};next_group=2;
  repeat(4)@(negedge clk);sv=15;
  repeat(4)@(negedge clk);ready_out=1;
  wait(accepted==1);@(negedge clk);ready_out=0;
  repeat(9)@(negedge clk);done=1;@(negedge clk);done=0;
  for(rounds=0;rounds<31;rounds=rounds+1)begin
   ready_out=0;repeat(3)@(negedge clk);ready_out=1;
   wait(accepted==rounds+2);@(negedge clk);ready_out=0;
   // Producer may now update the descriptor it just submitted.
   data_in[((next_group+3)%4)*32+:32]=32'h1000+rounds;
   repeat(7)@(negedge clk);
   if(!busy || valid_out)$fatal(1,"must lock until whole-record completion");
   done=1;@(negedge clk);done=0;
  end
  sv=0;repeat(4)@(negedge clk);
  if(busy||valid_out)$fatal(1,"did not return idle");
  sv=1;repeat(3)@(negedge clk);rst=1;
  repeat(2)@(negedge clk);sv=0;rst=0;
  repeat(4)@(negedge clk);if(busy||valid_out)$fatal(1,"reset descriptor survived");
  $display("PASS 32 nonpreemptive records with late arrivals and stalls");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
