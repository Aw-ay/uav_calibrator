`timescale 1ns/1ps
module tb_fine_bank_service;
 parameter integer TOTAL=256;
 reg clk_rf=0,clk_mem=0,rst_n=0;always #4 clk_rf=~clk_rf;always #2.5 clk_mem=~clk_mem;
 reg admit=0;reg [5:0] bank_ids=0,bad_channels=0;reg [255:0] request_key=0,frozen_noise=0;
 reg [3071:0] headers=0;reg [191:0] tops=0,peaks=0;reg [511:0] online_stats=0;reg [7:0] online_error=0;
 reg [15:0] publish=0,discard_pending=0,analysis_leased=0,record_leased=0,truncated=0;
 reg [1023:0] start_seq=0,generation=0;reg [239:0] sample_count=0;
 wire [15:0] analysis_pin,read_enable,read_lease;wire ack_analysis,idle_rf,result_valid;wire [3:0] ack_analysis_bank;
 wire [63:0] ack_analysis_epoch,ack_analysis_generation;wire [207:0] read_address;reg [2047:0] read_data=0;
 wire lost_valid;wire [1023:0] result_data;wire [31:0] errors;
 fine_bank_service #(.PRE_SAMPLES(30)) dut(.*);
 reg [63:0] samples[0:TOTAL-1];reg [1023:0] expected[0:2];reg fault_mode=0;integer losses=0;integer results=0,acks=0;integer requests[0:2];reg [2:0] seen=0;string root;
 function automatic [63:0] at_address(input integer a);integer k;begin k=(a-16383)&16383;at_address=k<TOTAL?samples[k]:64'hbadbadbadbadbadb;end endfunction
 always @(posedge clk_mem)if(rst_n)begin
  if(lost_valid)losses=losses+1;
  if(fault_mode&&(read_enable!=0||result_valid))$fatal(1,"failed descriptor touched RAM or published");
  for(integer b=0;b<12;b=b+1)if(read_enable[b])begin
   if(b%4!=0||record_leased[b]||!analysis_leased[b]||!read_lease[b])$fatal(1,"ownership/arbitration");
   if(read_address[b*13+:13]!==((8191+requests[b/4])&8191))$fatal(1,"read order");requests[b/4]=requests[b/4]+1;
   read_data[b*128+:128]<={at_address(2*read_address[b*13+:13]+1),at_address(2*read_address[b*13+:13])};
  end
  if(result_valid)begin
   if(result_data!==expected[result_data[295:288]-1])begin $display("actual=%0256x expected=%0256x",result_data,expected[result_data[295:288]-1]);$fatal(1,"complete service PDW");end
   if(seen[result_data[295:288]-1])$fatal(1,"duplicate result");seen[result_data[295:288]-1]=1;results=results+1;
  end
 end
 always @(posedge clk_rf)if(rst_n)begin
  if(ack_analysis)begin
   if(ack_analysis_epoch!=9||ack_analysis_generation!=17||!analysis_leased[ack_analysis_bank])$fatal(1,"return identity");
   if(requests[ack_analysis_bank/4]!=(TOTAL+2)/2)$fatal(1,"single odd pass request count");
   analysis_leased[ack_analysis_bank]<=0;acks=acks+1;
  end
 end
 initial begin
  if(!$value$plusargs("ROOT=%s",root))$fatal(1,"root");$readmemh({root,"/service_samples.hex"},samples);$readmemh({root,"/service_expected.hex"},expected);
  for(integer g=0;g<3;g=g+1)begin
   requests[g]=0;sample_count[g*60+:15]=TOTAL;start_seq[g*256+:64]=16383;generation[g*256+:64]=17;
   tops[g*32+:32]=121000000;tops[(g+3)*32+:32]=121000000;peaks[g*32+:32]=121000000;peaks[(g+3)*32+:32]=121000000;
   frozen_noise[g*32+:32]=1000;frozen_noise[(g+3)*32+:32]=1000;
   headers[g*1024+36*8+:32]=42;headers[g*1024+40*8+:64]=123456;
  end
  frozen_noise[197:192]=63;online_stats[290:276]=TOTAL-60;request_key[255:192]=11;request_key[191:128]=9;
  repeat(4)@(negedge clk_rf);rst_n=1;repeat(5)@(negedge clk_rf);admit=1;@(negedge clk_rf);admit=0;
  // Mutating producer inputs cannot change the frozen job.
  tops=0;peaks=0;frozen_noise=0;online_stats=0;request_key=0;headers=0;
  publish=1;discard_pending=16'h110;#1;if(analysis_pin!=16'h111)$fatal(1,"all ranges pinned");
  @(negedge clk_rf);analysis_leased=16'h111;record_leased=1;publish=0;discard_pending=0;
  wait(acks==2);@(negedge clk_rf);if(seen!=6||requests[0]!=0||idle_rf)$fatal(1,"selected bank must wait RAW; others proceed");record_leased=0;
  wait(acks==3);repeat(5)@(negedge clk_rf);if(!idle_rf||seen!=7||results!=3||errors!=0)$fatal(1,"completion");
  // An internal job rejection must release all identities and report each lost result.
  @(negedge clk_rf);fault_mode=1;sample_count=0;request_key[191:128]=9;admit=1;
  @(negedge clk_rf);admit=0;discard_pending=16'h111;
  @(negedge clk_rf);analysis_leased=16'h111;discard_pending=0;
  wait(acks==6);repeat(5)@(negedge clk_rf);
  if(!idle_rf||errors!=3||losses!=3||results!=3)$fatal(1,"failed analysis drain/accounting");
  $display("PASS Fine bank service: three ranges exact records N=%0d, frozen priors/identity, selected RAW priority, different-bank progress, natural reads per bank, drained returns, rejected jobs count losses and return leases",TOTAL);$finish;
 end
 initial begin #20000000;$fatal(1,"timeout state=%0d acks=%0d",dut.state,acks);end
endmodule
