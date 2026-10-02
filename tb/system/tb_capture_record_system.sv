`timescale 1ns/1ps
module tb_capture_record_system;
 reg rf=0,mem=0,rst_n=0;
 always #4 rf=~rf;
 initial begin #0.7;forever #2.5 mem=~mem;end
 reg reset_request=0,replay_quiescent=1,sample_valid=0;
 reg [63:0] sample_seq=0,primary_onset=0,aux_onset=0;
 reg primary_trigger=0,aux_trigger=0;
 reg [255:0] group_data=0;
 reg [15:0] eop_valid=0,stats_valid=0,publish=0,replay_pin=0;
 reg [1023:0] eop_stop=0,eop_generation=0,stats_generation=0;
 reg [3:0] desc_valid=0;wire [3:0] desc_ready;
 reg [4095:0] desc_headers=0;reg [7:0] desc_banks=0;
 reg [255:0] source_expected_epoch=0,source_expected_generation=0;
 wire [3:0] stale_descriptor;
 reg ack_replay=0;reg [3:0] ack_replay_bank=12;
 reg [63:0] ack_replay_epoch=0,ack_replay_generation=0;
 reg [15:0] replay_enable=0;reg [223:0] replay_address=0;
 reg [15:0] pending_stats_enable=0;reg [223:0] pending_stats_address=0;
 wire [1023:0] pending_stats_data;wire [15:0] pending_stats_valid;
 wire [1023:0] replay_data,start_seq,generation,pulse_id;
 wire [239:0] sample_count;
 wire [15:0] replay_valid,write_enable,armed,pending,frozen,truncated,qualified;
 wire [63:0] owner_epoch,completion_epoch,completion_generation;
 wire [31:0] rejected_returns,dropped_triggers,record_errors;
 wire quiesce,idle_rf,completion_valid,completion_error;
 wire [1:0] completion_group,completion_bank;
 wire [127:0] md;wire [15:0] mk;wire ml,mv;reg mr=0;wire [2:0] occupancy;
 capture_record_system #(.PRE_SAMPLES(3),.DETECTOR_LATENCY(1),.FIFO_ADDR_W(2),.STATS_PORT_ENABLED(1)) dut(
 .analysis_pin(16'd0),.ack_analysis(1'b0),.ack_analysis_bank(4'd0),.ack_analysis_epoch(64'd0),.ack_analysis_generation(64'd0),.analysis_leased(),.record_leased(),.fine_read_enable(16'd0),.fine_read_lease(16'd0),.fine_read_address(208'd0),.fine_read_data(),

  .clk_rf(rf),.clk_mem(mem),.rst_n(rst_n),.arm_enable(1'b1),.reset_request(reset_request),.replay_quiescent(replay_quiescent),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.group_data(group_data),
  .primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(64'd100),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(64'd103),
  .eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),.discard_pending(16'b0),
  .stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(16'hffff),.publish(publish),.replay_pin(replay_pin),
  .ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_generation),
  .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
  .pending_stats_enable(pending_stats_enable),.pending_stats_address(pending_stats_address),.pending_stats_data(pending_stats_data),.pending_stats_valid(pending_stats_valid),
  .desc_valid(desc_valid),.desc_ready(desc_ready),.desc_headers(desc_headers),.desc_banks(desc_banks),
  .source_expected_epoch(source_expected_epoch),.source_expected_generation(source_expected_generation),.stale_descriptor(stale_descriptor),
  .completion_valid(completion_valid),.completion_error(completion_error),.completion_epoch(completion_epoch),
  .completion_generation(completion_generation),.completion_group(completion_group),.completion_bank(completion_bank),.record_errors(record_errors),
  .write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
  .start_seq(start_seq),.sample_count(sample_count),.generation(generation),.pulse_id(pulse_id),.owner_epoch(owner_epoch),
  .rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.quiesce(quiesce),.idle_rf(idle_rf),
  .primary_admitted(),.aux_admitted(),.m_axis_tdata(md),.m_axis_tkeep(mk),.m_axis_tlast(ml),.m_axis_tvalid(mv),.m_axis_tready(mr),.fifo_occupancy(occupancy));
 reg [1023:0] h[0:5];reg [7:0] expected[0:1199];string root;
 integer total,out_bytes=0,completed=0,lasts=0,n,cycle=0,errors=0,early_reset=0,ram_reads=0,reads_before_stale;
 reg [3:0] taken=0;
 always @(posedge rf)begin
  if(rst_n&&(write_enable&frozen)!=0)$fatal(1,"write to frozen bank");
  taken=desc_valid&desc_ready;
  if(rst_n&&completion_valid)begin
   if(completion_error)errors=errors+1;else completed=completed+1;
   if(completion_bank!=0 || completion_epoch!=(completed<=5?0:1) || completion_generation!=(completed<=4?1:(completed==5?2:3)))
    if(!completion_error)$fatal(1,"completion token identity");
  end
 end
 always @(negedge rf)if(rst_n)desc_valid=desc_valid&~taken;
 always @(posedge mem)begin
  if(rst_n&&dut.record_enable!=0)ram_reads=ram_reads+1;
  if(rst_n&&(dut.record_enable&~frozen)!=0)$fatal(1,"record read without frozen owner");
  if(rst_n&&mv&&mr)begin
  for(integer b=0;b<16;b=b+1)if(mk[b])begin
   if(out_bytes>=total || md[b*8+:8]!==expected[out_bytes])$fatal(1,"captured byte mismatch %0d got %h expected %h",out_bytes,md[b*8+:8],expected[out_bytes]);
   out_bytes=out_bytes+1;
  end
  if(ml)lasts=lasts+1;
  end
 end
 task sample(input integer seq);
  begin
   @(negedge rf);sample_valid=1;sample_seq=seq;
   for(integer g=0;g<4;g=g+1)group_data[g*64+:64]={16'(-g),16'(seq+1),16'(g),16'(seq)};
  end
 endtask
 task finish_window(input [15:0] mask,input integer stop);
  begin
   @(negedge rf);sample_valid=0;primary_trigger=0;aux_trigger=0;
   eop_valid=mask;eop_generation=generation;for(integer j=0;j<16;j=j+1)eop_stop[j*64+:64]=stop;
   repeat(3)@(negedge rf);eop_valid=0;
   if((pending&mask)!=mask)$fatal(1,"not pending");
   for(integer g=0;g<4;g=g+1)pending_stats_address[g*4*14+:14]=start_seq[g*4*64+:14];
   pending_stats_enable=mask;
   @(negedge rf);
   if(pending_stats_valid!=mask)$fatal(1,"pending statistics A-port read");
   for(integer g=0;g<4;g=g+1)if(mask[g*4])begin
    if(pending_stats_data[g*4*64+:64]!={16'(-g),16'(start_seq[g*4*64+:64]+1),16'(g),16'(start_seq[g*4*64+:64])})$fatal(1,"pending statistics data");
   end
   pending_stats_enable=0;
   stats_valid=mask;stats_generation=generation;
   repeat(2)@(negedge rf);stats_valid=0;publish=mask;pending_stats_enable=mask;
   @(negedge rf);
   if(pending_stats_valid!=mask||replay_valid!=0)$fatal(1,"A response belongs to request before publish");
   publish=0;pending_stats_enable=0;
   if((frozen&mask)!=mask)$fatal(1,"not frozen");
  end
 endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("BYTES=%d",total))$fatal(1,"args");
  if($value$plusargs("EARLY_RESET=%d",early_reset))begin end
  $readmemh({root,"/headers.hex"},h);$readmemh({root,"/expected.hex"},expected);
  for(n=0;n<4;n=n+1)desc_headers[n*1024+:1024]=h[n];
  // Authoritative owner counts must replace all inconsistent caller lengths.
  for(n=0;n<4;n=n+1)begin
   desc_headers[n*1024+64+:64]=64'hffffffffffffffff;
   desc_headers[n*1024+512+:32]=32'hdeadbeef;
  end
  repeat(5)@(negedge rf);rst_n=1;repeat(5)@(negedge rf);
  // An unfrozen source must never be accepted or read.
  desc_valid=15;repeat(8)@(negedge rf);
  if(desc_ready!=0||mv||completed!=0)$fatal(1,"unfrozen descriptor accepted");desc_valid=0;
  for(n=16376;n<=16384;n=n+1)sample(n);
  primary_trigger=1;aux_trigger=1;primary_onset=16384;aux_onset=16384;
  sample(16385);primary_trigger=0;aux_trigger=0;
  sample(16386);sample(16387);replay_pin=16'h1000;replay_quiescent=0;
  finish_window(16'h1111,16388);
  if(start_seq[12*64+:64]!=16381||sample_count[12*15+:15]!=7)$fatal(1,"window");
  source_expected_epoch={4{owner_epoch}};
  for(n=0;n<4;n=n+1)source_expected_generation[n*64+:64]=generation[n*4*64+:64];
  desc_valid=15;
  wait(occupancy==4);repeat(30)@(negedge rf);
  if(completed!=0||frozen!=16'h1111)$fatal(1,"early release on full FIFO");
  mr=1;wait(completed==4);repeat(5)@(negedge rf);
  if(frozen!=16'h1000)$fatal(1,"replay must retain raw");
  desc_valid=8;repeat(8)@(negedge rf);
  if(desc_ready!=0||completed!=4)$fatal(1,"duplicate record from replay-pinned bank");desc_valid=0;
  replay_address[12*14+:14]=14'd16383;replay_enable=16'h1000;
  @(negedge rf);replay_enable=0;
  if(!replay_valid[12]||replay_data[12*64+:64]!={16'hfffd,16'd16384,16'd3,16'd16383})$fatal(1,"real replay read");
  ack_replay=1;ack_replay_generation=0;
  @(negedge rf);ack_replay=0;
  if(rejected_returns!=1||!frozen[12])$fatal(1,"stale replay return");
  ack_replay=1;ack_replay_generation=1;
  @(negedge rf);ack_replay=0;replay_quiescent=1;
  if(frozen[12])$fatal(1,"replay release");
  wait(out_bytes==800);mr=0;
  for(n=16396;n<=16404;n=n+1)sample(n);
  primary_trigger=1;primary_onset=16404;aux_trigger=1;aux_onset=16404;sample(16405);primary_trigger=0;aux_trigger=0;sample(16406);sample(16407);
  replay_pin=0;finish_window(16'h1111,16408);
  if(generation[12*64+:64]!=2)$fatal(1,"bank generation reuse");
  source_expected_epoch={4{owner_epoch}};
  for(n=0;n<4;n=n+1)source_expected_generation[n*64+:64]=generation[n*4*64+:64];
  desc_headers[3*1024+:1024]=h[4];desc_valid=8;
  if(early_reset!=0)begin
   // Arbiter has captured immutable payload but bridge has not accepted it yet.
   wait(!idle_rf);@(negedge rf);reset_request=1;replay_quiescent=0;
   #1;
   if(desc_ready!=8)$fatal(1,"selected source ready withdrawn by quiesce");
  end else begin
   wait(occupancy==4);@(negedge rf);reset_request=1;replay_quiescent=0;
  end
  // This source stays unselected, preserving an old bank0 header across reset.
  desc_valid[0]=1;
  repeat(30)@(negedge rf);
  if(owner_epoch!=0||write_enable!=0||!frozen[12])$fatal(1,"reset premature rearm");
  mr=1;wait(completed==5);wait(idle_rf);repeat(6)@(negedge rf);
  if(desc_valid!=1)$fatal(1,"selected descriptor was not acknowledged or unselected source was consumed during reset");
  if(owner_epoch!=0||!frozen[12])$fatal(1,"external replay quiescence ignored");
  replay_quiescent=1;wait(owner_epoch==1);repeat(3)@(negedge rf);
  if(frozen!=0||write_enable!=0)$fatal(1,"held reset");
  reset_request=0;wait(out_bytes==1000);mr=0;
  // Reject a caller header with an invalid schema; report loss and release RAW.
  for(n=16416;n<=16424;n=n+1)sample(n);
  primary_trigger=1;primary_onset=16424;aux_trigger=1;aux_onset=16424;sample(16425);primary_trigger=0;aux_trigger=0;sample(16426);sample(16427);
  finish_window(16'h1111,16428);
  reads_before_stale=ram_reads;
  repeat(30)@(negedge rf);
  if(!idle_rf||occupancy!=0||completed!=5||desc_valid!=1||stale_descriptor!=1||desc_ready!=0||ram_reads!=reads_before_stale||dut.submitted[0])
   $fatal(1,"stale unselected source reused new bank identity");
  // Correct epoch alone cannot attach stale-generation metadata to reused RAW.
  desc_valid=0;@(negedge rf);source_expected_epoch[0+:64]=owner_epoch;desc_valid=1;
  repeat(30)@(negedge rf);
  if(!idle_rf||stale_descriptor!=1||desc_ready!=0||completed!=5||ram_reads!=reads_before_stale||dut.submitted[0])$fatal(1,"stale generation accepted");
  // Correct generation alone cannot bypass an old owner epoch either.
  desc_valid=0;@(negedge rf);source_expected_epoch[0+:64]=owner_epoch-1;
  source_expected_generation[0+:64]=generation[0+:64];desc_valid=1;
  repeat(30)@(negedge rf);
  if(!idle_rf||stale_descriptor!=1||desc_ready!=0||completed!=5||ram_reads!=reads_before_stale||dut.submitted[0])$fatal(1,"stale epoch accepted");
  desc_valid=0;desc_headers[0+:1024]=h[5];source_expected_generation[0+:64]=generation[0+:64];
  source_expected_epoch[0+:64]=owner_epoch;
  @(negedge rf);desc_valid=1;mr=1;wait(completed==6);wait(out_bytes==total);mr=0;
  source_expected_epoch[3*64+:64]=owner_epoch;source_expected_generation[3*64+:64]=generation[12*64+:64];
  desc_headers[3*1024+32+:16]=16'd99;desc_valid=8;
  wait(errors==1);repeat(8)@(negedge rf);
  if(record_errors!=1||frozen[12]||occupancy!=0||lasts!=6||completed!=6)$fatal(1,"error accounting");
  $display("PASS capture record system: real RAM wrap, four groups, FIFO lease, replay, stale token, reuse, reset drain, stale source epoch/generation, rejection");$finish;
 end
 initial begin #200000;$fatal(1,"timeout completed=%0d bytes=%0d frozen=%h epoch=%0d",completed,out_bytes,frozen,owner_epoch);end
endmodule
