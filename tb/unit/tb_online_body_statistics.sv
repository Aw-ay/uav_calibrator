`timescale 1ns/1ps
module tb_online_body_statistics;
 parameter HOLD=125,LENGTH=27;
 reg clk=0;always #4 clk=~clk;reg rst=1;
 reg sample_valid=0;reg[63:0] sample_seq=0;reg[191:0] sample_power=0;reg[5:0] sample_good=63;
 reg start_valid=0;wire start_ready,start_accepted,start_rejected;wire[1:0] start_slot;
 reg[127:0] start_key=0;reg[63:0] onset_seq=0;reg[191:0] noise_power=0;reg[13:0] eop_hold=0;
 reg end_valid=0;reg[127:0] end_key=0;reg[63:0] end_seq=0;wire end_accepted,end_rejected;
 wire[3:0] occupied,result_valid;reg[3:0] result_ready=0;
 wire[511:0] result_key;wire[59:0] result_count;wire[1103:0] result_energy;
 wire[767:0] result_peak,result_top_signal;wire[23:0] result_bad;wire[31:0] result_error;
 wire start_eligible;
 online_body_statistics dut(.*);
 reg[688:0] expected[0:3];string root;integer ignored,cycle=0,accepted=0,ends=0;
 reg[3:0] seen=0;
 function automatic[31:0] power_at(input integer n,c);
  if(n%71==0)power_at=32'h80000000;else power_at=(n%37+c*3)*(n%37+c*3);
 endfunction
 always @(posedge clk)if(!rst)begin
  if(start_accepted)accepted=accepted+1;
  if(end_accepted)ends=ends+1;
  if(end_rejected)$fatal(1,"unexpected end rejection");
  for(integer s=0;s<4;s=s+1)if(result_valid[s])begin
   if(result_key[s*128+:128]!={64'd7,64'd100}+s)$fatal(1,"context identity");
   if({result_error[s*8+:8],result_bad[s*6+:6],result_count[s*15+:15],result_top_signal[s*192+:192],result_peak[s*192+:192],result_energy[s*276+:276]}!==expected[s])
    $fatal(1,"online body oracle mismatch slot%0d count%0d error%0d",s,result_count[s*15+:15],result_error[s*8+:8]);
   if(cycle<20+s*3+LENGTH+272)$fatal(1,"noncausal early result");
   seen[s]=1;
  end
 end
 initial begin
  ignored=$value$plusargs("ROOT=%s",root);$readmemh({root,"/online_expected.hex"},expected);
  for(integer c=0;c<6;c=c+1)noise_power[c*32+:32]=c*10;
  repeat(4)@(negedge clk);rst=0;
  for(cycle=0;cycle<20+9+LENGTH+HOLD+330;cycle=cycle+1)begin
   sample_valid=1;sample_seq=cycle;sample_good=(cycle==35)?6'h3e:6'h3f;
   for(integer c=0;c<6;c=c+1)sample_power[c*32+:32]=power_at(cycle,c);
   start_valid=0;end_valid=0;
   if(cycle==2)begin start_valid=1;start_key=99;onset_seq=10;eop_hold=257;end
   if(cycle==40)begin
    if(start_ready)$fatal(1,"full contexts reported ready");
    start_valid=1;start_key=199;onset_seq=40;eop_hold=HOLD;
   end
   for(integer s=0;s<4;s=s+1)begin
    if(cycle==20+s*3+2)begin start_valid=1;start_key={64'd7,64'd100}+s;onset_seq=20+s*3;eop_hold=HOLD;end
    if(cycle==20+s*3+LENGTH+HOLD+2)begin end_valid=1;end_key={64'd7,64'd100}+s;end_seq=20+s*3+LENGTH;end
   end
   @(negedge clk);
   if(cycle==2&&!start_rejected)$fatal(1,"hold257 accepted");
  end
  start_valid=0;end_valid=0;
  if(seen!=15||accepted!=4||ends!=4||occupied!=15)$fatal(1,"context accounting");
  repeat(20)@(negedge clk);result_ready=15;@(negedge clk);result_ready=0;
  if(occupied!=0||result_valid!=0)$fatal(1,"result release");
  $display("PASS online body statistics hold=%0d length=%0d four contexts TOP/energy/peak/tail exclusion",HOLD,LENGTH);$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
