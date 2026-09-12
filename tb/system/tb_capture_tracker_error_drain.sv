`timescale 1ns/1ps
module tb_capture_tracker_error_drain;
reg [239:0] malformed_counts;
 reg rf=0,mem=0,rst_n=0;
 always #4 rf=~rf;
 initial begin #0.7;forever #2.5 mem=~mem;end
 reg reset_request=0,replay_quiescent=1,sample_valid=0;
 reg [63:0] sample_seq=0,primary_onset=0,aux_onset=0;
 reg primary_trigger=0,aux_trigger=0;
 reg [255:0] group_data=0;
 reg [15:0] eop_valid=0;wire [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending;
 reg [1023:0] eop_stop=0,eop_generation=0;wire [1023:0] stats_generation;
 wire [3:0] desc_valid;wire [3:0] desc_ready;
 wire [4095:0] desc_headers;wire [7:0] desc_banks;
 wire [255:0] source_expected_epoch,source_expected_generation;
 wire [3:0] stale_descriptor;
 reg ack_replay=0;reg [3:0] ack_replay_bank=12;
 reg [63:0] ack_replay_epoch=0,ack_replay_generation=0;
 reg [15:0] replay_enable=0;reg [223:0] replay_address=0;
 wire [1023:0] replay_data,start_seq,generation,pulse_id;
 wire [239:0] sample_count;
 wire [15:0] replay_valid,write_enable,armed,pending,frozen,truncated,qualified;
 wire [63:0] owner_epoch,completion_epoch,completion_generation;
 wire [31:0] rejected_returns,dropped_triggers,record_errors;
 wire quiesce,idle_rf,completion_valid,completion_error;
 wire [1:0] completion_group,completion_bank;
 wire [127:0] md;wire [15:0] mk;wire ml,mv;reg mr=0;wire [2:0] occupancy;

 wire rst=!rst_n;
 reg begin_valid=0,measurement_valid=0,noise_valid=0,producers_idle=0;
 reg [255:0] begin_key=0,measurement_key=0,noise_key=0;
 reg [1023:0] config_data=0;reg [511:0] measurement_data=0;reg [255:0] noise_data=0;
 reg [191:0] bank_generations=0;reg [3071:0] headers=0;
 wire begin_ready,disposition_valid,descriptor_accepted,disposition_rejected;
 wire [7:0] statistics_error;wire block_new_work,reset_busy,reset_done;
 wire bridge_idle=dut.backend.bridge_idle;
 wire producer_error_valid;wire [7:0] producer_error_reason;wire onset_ready;
 calibrator_capture_system #(.PRE_SAMPLES(3),.DETECTOR_LATENCY(1),.FIFO_ADDR_W(2)) dut(
 .clk_rf(rf),.clk_mem(mem),.rst_n(rst_n),.arm_enable(1'b1),.reset_request(reset_request),.replay_quiescent(replay_quiescent),
 .sample_valid(sample_valid),.sample_seq(sample_seq),.group_data(group_data),.onset_valid(primary_trigger),.onset_ready(onset_ready),.onset_seq(primary_onset),.onset_gsc(64'd65536),.onset_pulse_id(64'd100),.config_version(64'd7),
 .onset_config(config_data),.onset_metadata(h[0]),.onset_noise(noise_data),.onset_bad_channels(6'd0),.onset_want_replay(1'b1),
 .eop_event_valid(eop_valid[0]),.eop_event_pulse_id(64'd100),.eop_event_owner_epoch(64'd0),.eop_event_stop(64'd16388),.eop_event_bad_channels(6'd0),
 .producer_error_valid(producer_error_valid),.producer_error_ready(1'b0),.producer_error_reason(producer_error_reason),
.statistics_error(statistics_error),
 .disposition_valid(disposition_valid),.descriptor_accepted(descriptor_accepted),.disposition_rejected(disposition_rejected),
 .ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_generation),
 .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
 .completion_valid(completion_valid),.completion_error(completion_error),.completion_epoch(completion_epoch),.completion_generation(completion_generation),.completion_group(completion_group),.completion_bank(completion_bank),
 .record_errors(record_errors),.rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
 .start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(sample_count),.owner_epoch(owner_epoch),.quiesce(quiesce),.idle_rf(idle_rf),.primary_admitted(),
 .block_new_work(block_new_work),.reset_busy(reset_busy),.reset_done(reset_done),
 .m_axis_tdata(md),.m_axis_tkeep(mk),.m_axis_tlast(ml),.m_axis_tvalid(mv),.m_axis_tready(mr),.fifo_occupancy(occupancy));
 reg [1023:0] h[0:2];reg [7:0] expected[0:199];string root;
 integer out_bytes=0,completed=0,lasts=0,accepted=0;
 always @(posedge rf)if(!rst)begin
  if(producer_error_valid)$fatal(1,"producer context error %0d",producer_error_reason);
  if((write_enable&frozen)!=0)$fatal(1,"write frozen");
  if(descriptor_accepted)accepted=accepted+1;
  if(disposition_rejected)$fatal(1,"unexpected descriptor rejection");
  if(completion_valid)begin
   if(completion_error||completion_group!=1||completion_bank!=0||completion_generation!=1||completion_epoch!=0)$fatal(1,"completion identity");
   completed=completed+1;
  end
 end
 always @(posedge mem)if(rst_n&&mv&&mr)begin
  for(integer b=0;b<16;b=b+1)if(mk[b])begin
   if(out_bytes>=200||md[b*8+:8]!==expected[out_bytes])$fatal(1,"byte %0d got %h expected %h",out_bytes,md[b*8+:8],expected[out_bytes]);
   out_bytes=out_bytes+1;
  end
  if(ml)begin if(out_bytes!=200)$fatal(1,"TLAST position");lasts=lasts+1;end
 end
 task tick;begin @(posedge rf);#1;@(negedge rf);end endtask
 task sample(input integer seq);begin
  sample_valid=1;sample_seq=seq;
  for(integer g=0;g<4;g=g+1)group_data[g*64+:64]={16'(-g),16'(seq+1),16'(g),16'(seq)};
  tick();
 end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root))$fatal(1,"ROOT required");
  $readmemh({root,"/headers.hex"},h);$readmemh({root,"/expected.hex"},expected);
  repeat(5)tick();rst_n=1;repeat(5)tick();
  for(integer c=0;c<6;c=c+1)begin config_data[c*32+:32]=65536;measurement_data[c*46+:46]=700;noise_data[c*32+:32]=25;end
  config_data[239:224]=6553;config_data[223:192]=65536;config_data[245:240]=6'b100001;
  config_data[251:246]=63;config_data[257:252]=63;config_data[263:258]=63;
  measurement_data[290:276]=7;measurement_data[299:297]=7;noise_data[197:192]=63;
  for(integer n=16376;n<=16384;n=n+1)sample(n);
  if(!onset_ready)$fatal(1,"onset admission unavailable");
  primary_trigger=1;primary_onset=16384;sample(16385);primary_trigger=0;config_data=0;noise_data=0;sample(16386);sample(16387);
  sample_valid=0;eop_valid=16'h0111;eop_generation=generation;eop_stop={16{64'd16388}};
  tick();eop_valid=0;wait(pending==16'h0111);

  // Owner identities remain valid and PENDING; corrupt one exported window count.
  malformed_counts=sample_count;malformed_counts[4*15+:15]=sample_count[4*15+:15]+1'b1;
  force dut.tracker.sample_count=malformed_counts;
  reset_request=1;replay_quiescent=1;mr=1;
  for(integer n=0;n<150&&!reset_done;n=n+1)tick();
  if(owner_epoch!=1||pending!=0||frozen!=0||accepted!=0||completed!=0||out_bytes!=0)$fatal(1,"window mismatch failed to drain reset safely");
  if(dut.context_error_count!=1||producer_error_valid)$fatal(1,"window geometry must be discard request, not held producer error");
  release dut.tracker.sample_count;
  $display("PASS tracker error drainage: mismatched pending windows discard all banks and reset completes");$finish;
 end
 initial begin #200000;$fatal(1,"error drain timeout");end
endmodule

