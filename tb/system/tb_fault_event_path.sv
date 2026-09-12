`timescale 1ns/1ps
module tb_fault_event_path;
 reg clk=0,rst=1,in_valid=0;reg [255:0] in_data=0;
 wire fault_valid,fault_ready,saturated;wire [255:0] snapshot;wire [31:0] occurrences;
 fault_event_retainer keep(.clk(clk),.rst(rst),.in_valid(in_valid),.in_data(in_data),.out_valid(fault_valid),.out_ready(fault_ready),.out_data(snapshot),.out_occurrences(occurrences),.out_saturated(saturated));
 // Test-only packing; the production EVENT format is intentionally not defined here.
 wire [511:0] fault_data={223'd0,saturated,occurrences,snapshot};
 reg normal_valid=0,out_ready=0;reg [511:0] normal_data=0;
 wire normal_ready,out_valid,out_is_fault;wire [511:0] out_data;
 event_priority_arbiter merge(.*);always #4 clk=~clk;
 integer faults_sent=0,faults_seen=0,normals_sent=0,normals_seen=0;reg na=0;
 reg [31:0] rng=32'h31c046ac;
 task step(input bit inject,offer,ready);begin
  @(negedge clk);out_ready=ready;in_valid=inject;
  if(inject)begin faults_sent=faults_sent+1;in_data={224'd0,32'(faults_sent)};end
  if(!normal_valid||na)begin normal_valid=offer;normal_data={16{32'(normals_sent+1)}};end
  #1;
  if(out_valid&&out_ready)begin
   if(out_is_fault)begin
    if(out_data[511:288]!=0||out_data[287:256]==0||out_data[255:0]!=={224'd0,32'(faults_seen+1)})$fatal(1,"fault aggregate identity/count");
    faults_seen=faults_seen+out_data[287:256];if(faults_seen>faults_sent)$fatal(1,"fabricated fault");
   end else begin
    normals_seen=normals_seen+1;if(out_data!=={16{32'(normals_seen)}})$fatal(1,"normal identity/order");
   end
  end
  na=normal_valid&&normal_ready;if(na)normals_sent=normals_sent+1;
  if(fault_valid&&normal_ready)$fatal(1,"path fault priority");
  @(posedge clk);#1;
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  step(0,1,0);repeat(40)step(1,1,0);
  if(!out_valid||out_is_fault||faults_seen)$fatal(1,"blocked normal overwritten");
  repeat(8)step(0,0,1);if(faults_sent!=faults_seen||normals_sent!=normals_seen)$fatal(1,"burst conservation");
  for(integer k=0;k<1500;k=k+1)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};step(rng[0]||rng[5],rng[4],rng[6]||k%11==0);end
  repeat(10)step(0,0,1);
  if(faults_sent!=faults_seen||normals_sent!=normals_seen||fault_valid||out_valid||normal_valid)$fatal(1,"final conservation");
  $display("PASS fault event path faults=%0d normals=%0d aggregation priority backpressure",faults_seen,normals_seen);$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
