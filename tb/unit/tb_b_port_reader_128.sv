`timescale 1ns/1ps
module tb_b_port_reader_128;
 parameter LATENCY=1,FIFO_WORDS=8;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,desc_valid=0,word_ready=0;
 reg[13:0] start_ptr=0;reg[14:0] sample_count=0;
 wire desc_ready,ram_en,word_valid,first,last,done,rejected,busy;
 wire[12:0] ram_addr;wire[127:0] word_data;wire[1:0] mask;wire[14:0] index;
 reg[127:0] delay_data[0:LATENCY-1];wire[127:0] ram_data=delay_data[LATENCY-1];
 b_port_reader_128 #(.READ_LATENCY_B(LATENCY),.FIFO_WORDS(FIFO_WORDS)) dut(.*,.word_mask(mask),.word_first(first),.word_last(last),.word_index(index));
 integer j,seen,requests,received_words,origin,total,cycle,prev_req,max_streak,streak;
 reg checking=0,random_stall=0;reg[31:0] rng=32'h6824abcd;
 reg stalled=0;reg[147:0] held;
 function automatic[63:0] sample(input integer n);sample=64'habcd123400000000+(n&16383);endfunction
 always @(posedge clk) begin
  if(ram_en)delay_data[0]<={sample(2*ram_addr+1),sample(2*ram_addr)};
  for(j=1;j<LATENCY;j=j+1)delay_data[j]<=delay_data[j-1];
  if(checking)begin
   if(ram_en)begin
    if(ram_addr!==((origin/2+requests)&8191))$fatal(1,"request address %0d",requests);
    requests=requests+1;streak=streak+1;if(streak>max_streak)max_streak=streak;
   end else streak=0;
   if(stalled && !abort && {word_valid,word_data,mask,first,last,index}!==held)$fatal(1,"unstable stalled output");
   stalled=word_valid&&!word_ready&&!abort;held={word_valid,word_data,mask,first,last,index};
   if(requests-received_words>FIFO_WORDS-1)$fatal(1,"unreserved response credit");
   if(word_valid&&word_ready)begin
    received_words=received_words+1;
    if(index!==seen || first!==(seen==0))$fatal(1,"index/first");
    if(mask[0])begin if(word_data[63:0]!==sample(origin+seen))$fatal(1,"low sample %0d",seen);seen=seen+1;end
    if(mask[1])begin if(word_data[127:64]!==sample(origin+seen))$fatal(1,"high sample %0d",seen);seen=seen+1;end
    if(mask==0||last!==(seen==total))$fatal(1,"mask/last seen%0d total%0d",seen,total);
   end
  end
 end
 always @(negedge clk)begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  word_ready=checking && (!random_stall || rng[3:0]>5);
 end
 task automatic run(input integer s,n,stall);
 begin
  wait(desc_ready);@(negedge clk);start_ptr=s;sample_count=n;desc_valid=1;
  origin=s;total=n;seen=0;requests=0;received_words=0;max_streak=0;streak=0;stalled=0;checking=1;random_stall=stall;
  @(negedge clk);desc_valid=0;
  wait(done);#1;checking=0;
  if(seen!=n||requests!=((s%2+n+1)/2))$fatal(1,"count seen%0d req%0d n%0d",seen,requests,n);
  if(!stall&&n>64&&max_streak<32)$fatal(1,"reader not one request/cycle steady state: %0d",max_streak);
  @(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  run(0,1,0);run(1,1,0);run(0,2,1);run(1,2,1);run(16383,3,1);run(16383,16384,1);run(17,1000,0);
  for(integer k=0;k<30;k=k+1)run((k*379+1)&16383,k*31+1,1);
  // Reject illegal length without issuing any RAM request.
  @(negedge clk);desc_valid=1;sample_count=0;
  @(negedge clk);desc_valid=0;if(!rejected||ram_en)$fatal(1,"zero not rejected");
  @(negedge clk);desc_valid=1;sample_count=16385;
  @(negedge clk);desc_valid=0;if(!rejected||ram_en)$fatal(1,"oversize not rejected");
  // Sweep cancellation from no request through full FIFO, with no consumer.
  for(integer k=0;k<FIFO_WORDS+LATENCY+3;k=k+1)begin
   @(negedge clk);desc_valid=1;sample_count=1000;
   @(negedge clk);desc_valid=0;
   repeat(k)@(negedge clk);abort=1;#0.1;
   if(ram_en)$fatal(1,"request on abort");
   @(negedge clk);abort=0;
   wait(done);if(busy||dut.pending!=0)$fatal(1,"early abort return");
   run(27,97,1);
  end
  $display("PASS B128 reader latency=%0d FIFO=%0d parity/wrap/fullwindow/stalls/abort/throughput",LATENCY,FIFO_WORDS);$finish;
 end
 initial begin #5000000;$fatal(1,"timeout");end
endmodule
