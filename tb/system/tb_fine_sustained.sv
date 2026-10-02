`timescale 1ns/1ps
module tb_fine_sustained;
 parameter integer TOTAL=16384,PULSES=12;
 reg clk_rf=0,clk_mem=0,rst_n=0;always #4 clk_rf=~clk_rf;always #2.5 clk_mem=~clk_mem;
 reg admit=0;reg [5:0] bank_ids=0,bad_channels=0;reg [255:0] request_key=0,frozen_noise=0;
 reg [3071:0] headers=0;reg [191:0] tops=0,peaks=0;reg [511:0] online_stats=0;reg [7:0] online_error=0;
 reg [15:0] publish=0,discard_pending=0,analysis_leased=0,record_leased=0,truncated=0;
 reg [1023:0] start_seq=0,generation=0;reg [239:0] sample_count=0;
 wire [15:0] analysis_pin,read_enable,read_lease;wire ack_analysis,idle_rf,result_valid;wire [3:0] ack_analysis_bank;
 wire [63:0] ack_analysis_epoch,ack_analysis_generation;wire [207:0] read_address;wire [2047:0] read_data;
 wire lost_valid;wire [1023:0] result_data;wire [31:0] errors;
 fine_bank_service #(.PRE_SAMPLES(30)) dut(.*);
 reg [63:0] samples[0:TOTAL-1];reg [1023:0] expected[0:2];integer results=0,acks=0,pulse_number=0,mem_cycles=0,first_cycle=0,worst_cycles=0;reg concurrent_b=0,concurrent_ab=0;integer requests[0:2];reg [2:0] seen=0;string root;
 reg [15:0] writes=0;reg [13:0] write_address=0;reg [255:0] write_data=0;
 reg storage_frozen=0;wire [15:0] dma_enable;wire [207:0] storage_address;
 wire [15:0] replay_enable;wire [223:0] replay_address;wire [1023:0] replay_data;wire [15:0] replay_valid;
 reg replay_active=0;reg [14:0] replay_index=0;integer replay_received=0;
 assign replay_enable=replay_active?16'h1:16'd0;
 for(genvar c=0;c<16;c=c+1)begin
  assign replay_address[c*14+:14]=14'd16383+replay_index[13:0];
  assign storage_address[c*13+:13]=read_lease[c]?read_address[c*13+:13]:dma_address;
 end
 capture_bank_array storage(.clk_rf(clk_rf),.clk_mem(clk_mem),.quiesce_rf(!rst_n),.quiesce_mem(!rst_n),
  .group_data(write_data),.write_enable(writes),.write_address(write_address),.frozen_rf({16{storage_frozen}}),.frozen_mem(read_lease|dma_enable),
  .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
  .record_enable(read_enable|dma_enable),.record_address(storage_address),.record_data(read_data),.record_valid());
 reg dma_job=0;wire dma_ready,dma_busy,dma_done,dma_reject,dma_en,dma_valid,dma_first,dma_last;
 wire [12:0] dma_address;wire [127:0] dma_word;wire [1:0] dma_mask;wire [14:0] dma_index;
 integer dma_words=0;
 assign dma_enable=dma_en?16'h1:16'd0;
 b_port_reader_128 dma(.clk(clk_mem),.rst(!rst_n),.abort(1'b0),.desc_valid(dma_job),.desc_ready(dma_ready),
  .start_ptr(14'd16383),.sample_count(15'd16384),.ram_en(dma_en),.ram_addr(dma_address),.ram_data(read_data[127:0]),
  .word_valid(dma_valid),.word_ready(1'b1),.word_data(dma_word),.word_mask(dma_mask),.word_index(dma_index),.word_first(dma_first),.word_last(dma_last),
  .done(dma_done),.rejected(dma_reject),.busy(dma_busy));
 always @(posedge clk_mem)begin
  mem_cycles=mem_cycles+1;
  if(rst_n)begin
   if(|(read_lease&dma_enable))$fatal(1,"same bank B collision");
   if(read_enable!=0&&dma_enable!=0)concurrent_b=1;
   if(read_enable[0]&&replay_active)concurrent_ab=1;
   if(dma_reject)$fatal(1,"RAW reject");
   if(dma_valid)begin
    if(dma_mask[0]&&dma_word[63:0]!==samples[dma_index])$fatal(1,"RAW low sample");
    if(dma_mask[1]&&dma_word[127:64]!==samples[dma_index+(dma_mask[0]?1:0)])$fatal(1,"RAW high sample");
    dma_words=dma_words+1;
   end
  end
 end
 always @(posedge clk_rf)if(rst_n)begin
  if(replay_active)begin if(replay_index==TOTAL-1)replay_active<=0;else replay_index<=replay_index+1'b1;end
  if(replay_valid[0])begin
   if(replay_data[63:0]!==samples[replay_received])$fatal(1,"A replay changed by B consumers");
   replay_received=replay_received+1;
  end
 end
 function automatic [63:0] at_address(input integer a);integer k;begin k=(a-16383)&16383;at_address=samples[k];end endfunction
 always @(posedge clk_mem)if(rst_n)begin
  for(integer b=0;b<12;b=b+1)if(read_enable[b])begin
   if(b%4!=0||record_leased[b]||!analysis_leased[b]||!read_lease[b])$fatal(1,"ownership/arbitration");
   if(read_address[b*13+:13]!==((8191+requests[b/4])&8191))$fatal(1,"read order");requests[b/4]=requests[b/4]+1;

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
  repeat(4)@(negedge clk_rf);rst_n=1;repeat(5)@(negedge clk_rf);
  writes=16'hffff;
  for(integer n=0;n<TOTAL;n=n+1)begin write_address=n;write_data={4{at_address(n)}};@(negedge clk_rf);end
  writes=0;storage_frozen=1;first_cycle=mem_cycles;
  for(pulse_number=0;pulse_number<PULSES;pulse_number=pulse_number+1)begin : pulse
   integer start_cycle;
   while(mem_cycles<first_cycle+pulse_number*60606)@(negedge clk_rf);
   if(analysis_leased!=0||!idle_rf)$fatal(1,"F7 backlog exceeded pulse period");
   for(integer g=0;g<3;g=g+1)begin requests[g]=0;expected[g][127:64]=11+pulse_number;end
   results=0;acks=0;seen=0;dma_words=0;replay_received=0;replay_index=0;
   request_key[255:192]=11+pulse_number;admit=1;@(negedge clk_rf);admit=0;
   publish=1;discard_pending=16'h110;#1;if(analysis_pin!=16'h111)$fatal(1,"all ranges pinned");
   @(negedge clk_rf);analysis_leased=16'h111;record_leased=1;publish=0;discard_pending=0;
   start_cycle=mem_cycles;
   @(negedge clk_mem);dma_job=1;@(negedge clk_mem);dma_job=0;
   wait(dma_done);@(negedge clk_rf);if(dma_words!=8193)$fatal(1,"full RAW count");record_leased=0;replay_active=1;
   wait(acks==3);repeat(3)@(negedge clk_rf);
   if(!idle_rf||results!=3||seen!=7||errors!=0||replay_received!=TOTAL)$fatal(1,"pulse completion");
   if(mem_cycles-start_cycle>worst_cycles)worst_cycles=mem_cycles-start_cycle;
   if(mem_cycles-start_cycle>=60606)$fatal(1,"F7 service time %0d exceeds3.3kHz",mem_cycles-start_cycle);
  end
  if(!concurrent_b||!concurrent_ab)$fatal(1,"concurrent physical ports were not exercised");
  $display("PASS Fine F7 actual16-bank RAM: pulses=%0d ranges=%0d samples_per_range=%0d period_cycles=60606 worst_three_range_cycles=%0d; full RAW B concurrent, same-bank exclusion, same-bank A replay exact, bounded backlog no lost jobs",PULSES,3*PULSES,TOTAL,worst_cycles);$finish;
 end
 initial begin #10000000;$fatal(1,"timeout state=%0d acks=%0d",dut.state,acks);end
endmodule
