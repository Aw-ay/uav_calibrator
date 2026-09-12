`timescale 1ns/1ps
module tb_event_priority_arbiter;
 reg clk=0,rst=1,fault_valid=0,normal_valid=0,out_ready=0;
 reg [511:0] fault_data=0,normal_data=0;wire fault_ready,normal_ready,out_valid,out_is_fault;wire [511:0] out_data;
 event_priority_arbiter dut(.*);always #4 clk=~clk;
 reg [511:0] expected[0:8191];reg expected_fault[0:8191];integer wr=0,rd=0,serial=0;
 reg fa=0,na=0;reg [31:0] rng=32'h17acde09;reg held;reg [511:0] old_data;reg old_kind;
 always @(posedge clk)begin
  if(rst)begin wr=0;rd=0;fa=0;na=0;end
  else begin
   held=out_valid&&!out_ready;old_data=out_data;old_kind=out_is_fault;
   if(fault_valid&&normal_ready)$fatal(1,"fault priority violated");
   if(out_valid&&out_ready)begin
    if(rd==wr||out_data!==expected[rd]||out_is_fault!==expected_fault[rd])$fatal(1,"delivery identity/order");rd=rd+1;
   end
   fa=fault_valid&&fault_ready;na=normal_valid&&normal_ready;
   if(fa)begin expected[wr]=fault_data;expected_fault[wr]=1;wr=wr+1;end
   if(na)begin expected[wr]=normal_data;expected_fault[wr]=0;wr=wr+1;end
   #1;if(held&&(!out_valid||out_data!==old_data||out_is_fault!==old_kind))$fatal(1,"blocked record changed");
   if(!out_valid&&(out_data!==0||out_is_fault))$fatal(1,"empty output");
  end
 end
 task drive(input bit f,n,r);begin
  @(negedge clk);out_ready=r;
  if(!fault_valid||fa)begin fault_valid=f;if(f)begin serial=serial+1;fault_data={16{32'(serial)}};end end
  if(!normal_valid||na)begin normal_valid=n;if(n)begin serial=serial+1;normal_data={16{32'(serial)}};end end
  @(posedge clk);#2;
 end endtask
 initial begin
  repeat(3)@(negedge clk);if(fault_ready||normal_ready||out_valid)$fatal(1,"reset handshake");rst=0;
  drive(0,1,0);drive(1,1,0);repeat(5)drive(1,1,0);
  if(out_is_fault)$fatal(1,"preempted normal");
  drive(1,1,1);if(!out_is_fault)$fatal(1,"fault next");
  for(integer k=0;k<2000;k=k+1)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};drive(rng[0],rng[4],rng[7]||k%7==0);end
  repeat(5)drive(0,0,1);if(wr!=rd||out_valid||fault_valid||normal_valid)$fatal(1,"drain");
  $display("PASS arbiter ordered records=%0d",rd);
  drive(1,1,0);@(negedge clk);rst=1;#1;if(out_valid||fault_ready||normal_ready)$fatal(1,"reset pending");
  @(posedge clk);#2;@(negedge clk);fault_valid=0;normal_valid=0;rst=0;
  drive(0,1,1);repeat(3)drive(0,0,1);if(wr!=rd)$fatal(1,"reset recovery");
  $display("PASS event priority arbiter priority stable identity simultaneous reset");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
