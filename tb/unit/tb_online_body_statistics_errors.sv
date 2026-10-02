`timescale 1ns/1ps
module tb_online_body_statistics_errors;
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

 task automatic step;
 begin @(negedge clk);sample_seq=sample_seq+1'b1;@(posedge clk);#1;end
 endtask
 task automatic reset;
 begin
  rst=1;start_valid=0;end_valid=0;result_ready=0;sample_valid=1;sample_good=63;
  sample_power={6{32'd1}};noise_power=0;eop_hold=125;
  repeat(3)step();rst=0;step();
 end endtask
 task automatic start;
 begin start_key={64'd7,64'd9};onset_seq=sample_seq+1'b1;start_valid=1;step();start_valid=0;
  if(!start_accepted||occupied!=1)$fatal(1,"start error");
 end endtask
 initial begin
  reset();start();
  start_valid=1;step();start_valid=0;
  if(!start_rejected||occupied!=1)$fatal(1,"duplicate key accepted");
  end_valid=1;end_key={64'd8,64'd9};end_seq=onset_seq+5;step();end_valid=0;
  if(!end_rejected)$fatal(1,"wrong owner accepted");
  sample_seq=sample_seq+100;step();
  if(result_valid!=1||result_error[7:0]!=8||result_bad[5:0]!=63)$fatal(1,"sequence gap not failed closed");
  repeat(20)step();
  if(result_valid!=1||result_key[127:0]!=start_key)$fatal(1,"held error changed");
  result_ready=1;step();result_ready=0;if(occupied!=0)$fatal(1,"result not freed");
  reset();start();repeat(350)step();
  end_valid=1;end_key=start_key;end_seq=onset_seq+5;step();end_valid=0;
  if(!end_accepted||result_valid!=1||result_error[7:0]!=2||result_bad[5:0]!=63)$fatal(1,"late end not rejected");
  reset();start();end_valid=1;end_key=start_key;end_seq=onset_seq+16385;step();end_valid=0;
  if(result_valid!=1||result_error[7:0]!=1)$fatal(1,"oversize end not rejected");
  reset();start();repeat(16700)step();
  if(result_valid!=1||result_error[7:0]!=4||result_count[14:0]!=16384)$fatal(1,"unterminated body overflow");
  reset();start();repeat(10)step();
  // Cold reset invalidates delayed old samples without clearing payload RAM.
  reset();start();end_valid=1;end_key=start_key;end_seq=onset_seq+1;step();end_valid=0;
  repeat(300)step();
  if(result_valid!=1||result_error[7:0]!=0||result_count[14:0]!=1||result_energy[45:0]!=1)$fatal(1,"reset data leak");
  rst=1;step();sample_seq=64'hfffffffffffffff0;rst=0;step();start();repeat(30)step();
  if(result_valid!=1||result_error[7:0]!=8)$fatal(1,"rollover not failed closed");
  $display("PASS online body errors duplicate/stale/end-bound/late/gap/overflow/reset/rollover");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
