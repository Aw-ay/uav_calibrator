`timescale 1ns/1ps
module tb_qualified_record_upload;
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
 capture_record_system #(.PRE_SAMPLES(3),.DETECTOR_LATENCY(1),.FIFO_ADDR_W(2)) dut(
 .analysis_pin(16'd0),.ack_analysis(1'b0),.ack_analysis_bank(4'd0),.ack_analysis_epoch(64'd0),.ack_analysis_generation(64'd0),.analysis_leased(),.record_leased(),.fine_read_enable(16'd0),.fine_read_lease(16'd0),.fine_read_address(208'd0),.fine_read_data(),

  .clk_rf(rf),.clk_mem(mem),.rst_n(rst_n),.arm_enable(1'b1),.reset_request(reset_request),.replay_quiescent(replay_quiescent),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.group_data(group_data),
  .primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(64'd100),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(64'd103),
  .eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),.discard_pending(discard_pending),
  .stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
  .ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_generation),
  .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
  .desc_valid(desc_valid),.desc_ready(desc_ready),.desc_headers(desc_headers),.desc_banks(desc_banks),
  .source_expected_epoch(source_expected_epoch),.source_expected_generation(source_expected_generation),.stale_descriptor(stale_descriptor),
  .completion_valid(completion_valid),.completion_error(completion_error),.completion_epoch(completion_epoch),
  .completion_generation(completion_generation),.completion_group(completion_group),.completion_bank(completion_bank),.record_errors(record_errors),
  .write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
  .start_seq(start_seq),.sample_count(sample_count),.generation(generation),.pulse_id(pulse_id),.owner_epoch(owner_epoch),
  .rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.quiesce(quiesce),.idle_rf(idle_rf),
  .primary_admitted(),.aux_admitted(),.m_axis_tdata(md),.m_axis_tkeep(mk),.m_axis_tlast(ml),.m_axis_tvalid(mv),.m_axis_tready(mr),.fifo_occupancy(occupancy));

 reg [1:0] reset_sync=0;
 always @(posedge rf or negedge rst_n)if(!rst_n)reset_sync<=0;else reset_sync<={reset_sync[0],1'b1};
 wire rst=!reset_sync[1];
 reg begin_valid=0,measurement_valid=0,noise_valid=0;
 reg [255:0] begin_key=0,measurement_key=0,noise_key=0;
 reg [1023:0] config_data=0;reg [511:0] measurement_data=0;reg [255:0] noise_data=0;
 reg [191:0] bank_generations=0;reg [3071:0] headers=0;
 wire begin_ready,measurement_ready,noise_ready,event_ready,event_valid,event_published,event_rejected,bridge_idle;
 wire [255:0] event_key;wire [3:0] event_bank;wire [1023:0] event_header;wire [63:0] event_generation,event_epoch;
 wire disposition_valid,descriptor_accepted,disposition_rejected;
 qualification_publish_bridge qualification(.measurement_peaks(192'd0),.event_stats(),.event_peaks(),
 .clk(rf),.rst(rst),.quiesce(quiesce),.begin_valid(begin_valid),.begin_ready(begin_ready),.want_replay(1'b1),
 .begin_key(begin_key),.config_data(config_data),.bank_ids(6'd0),.bank_generations(bank_generations),.headers(headers),
 .measurement_valid(measurement_valid),.measurement_key(measurement_key),.measurement_data(measurement_data),.measurement_ready(measurement_ready),
 .noise_valid(noise_valid),.noise_key(noise_key),.noise_data(noise_data),.noise_ready(noise_ready),
 .pending(pending),.qualified(qualified),.generation(generation),.pulse_id(pulse_id),.owner_epoch(owner_epoch),
 .stats_valid(stats_valid),.stats_good(stats_good),.stats_generation(stats_generation),.publish(publish),.replay_pin(replay_pin),.discard_pending(discard_pending),
 .event_valid(event_valid),.event_ready(event_ready),.event_published(event_published),.event_rejected(event_rejected),
 .event_key(event_key),.event_bank(event_bank),.event_header(event_header),.event_generation(event_generation),.event_epoch(event_epoch),
 .begin_rejected(),.measurement_rejected(),.noise_rejected(),.idle(bridge_idle));
 qualification_record_source source(.rst(rst),.*);
 reg [1023:0] h[0:2];reg [7:0] expected[0:199];string root;
 integer out_bytes=0,completed=0,lasts=0,accepted=0;
 always @(posedge rf)if(!rst)begin
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
  for(integer n=16376;n<=16384;n=n+1)sample(n);
  primary_trigger=1;primary_onset=16384;sample(16385);primary_trigger=0;sample(16386);sample(16387);
  sample_valid=0;eop_valid=16'h0111;eop_generation=generation;eop_stop={16{64'd16388}};
  tick();eop_valid=0;tick();if(pending!=16'h0111)$fatal(1,"pending");
  bank_generations={generation[512+:64],generation[256+:64],generation[0+:64]};
  begin_key={64'd100,owner_epoch,generation[0+:64],64'd7};measurement_key=begin_key;noise_key=begin_key;
  headers={h[2],h[1],h[0]};
  for(integer c=0;c<6;c=c+1)begin config_data[c*32+:32]=65536;measurement_data[c*46+:46]=700;noise_data[c*32+:32]=25;end
  config_data[223:192]=65536;config_data[245:240]=6'b100001;
  config_data[251:246]=63;config_data[257:252]=63;config_data[263:258]=63;
  measurement_data[290:276]=7;measurement_data[299:297]=7;noise_data[197:192]=63;
  begin_valid=1;tick();begin_valid=0;headers=0;config_data=0;
  measurement_valid=1;noise_valid=1;tick();measurement_valid=0;noise_valid=0;
  wait(occupancy==4);repeat(20)tick();
  if(completed!=0||frozen!=16'h0010||accepted!=1)$fatal(1,"FIFO stall must retain RAW");
  mr=1;wait(out_bytes==200&&completed==1);repeat(5)tick();
  if(frozen!=16'h0010||accepted!=1||lasts!=1||!bridge_idle)$fatal(1,"single frame plus replay lease");
  replay_address[4*14+:14]=14'd16383;replay_enable=16'h0010;tick();replay_enable=0;
  if(!replay_valid[4]||replay_data[4*64+:64]!={16'hffff,16'd16384,16'd1,16'd16383})$fatal(1,"replay data");
  ack_replay_bank=4;ack_replay_epoch=0;ack_replay_generation=0;ack_replay=1;tick();ack_replay=0;
  if(rejected_returns!=1||!frozen[4])$fatal(1,"stale release");
  ack_replay_generation=1;ack_replay=1;tick();ack_replay=0;tick();
  if(frozen!=0||pending!=0||record_errors!=0)$fatal(1,"final release");
  $display("PASS qualified record upload real qualification RAM CRC CDC FIFO replay ownership");$finish;
 end
 initial begin #200000;$fatal(1,"timeout bytes=%0d completed=%0d",out_bytes,completed);end
endmodule
