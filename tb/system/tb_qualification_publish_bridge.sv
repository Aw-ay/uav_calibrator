`timescale 1ns/1ps
module tb_qualification_publish_bridge;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,reset_request=0,sample_valid=0,trig=0;
 reg [63:0] sample_seq=0,onset=0,pulse=77;
 reg [15:0] eop_valid=0;reg [1023:0] eop_stop=0,eop_gen=0;
 wire [15:0] write_enable,armed,pending,frozen,truncated,qualified;
 wire [1023:0] generation,pulse_id,start_seq;wire [63:0] counts,owner_epoch;
 wire [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending;
 wire [1023:0] stats_generation;wire quiesce;
 capture_bank_manager #(.ADDR_W(3),.PRE_SAMPLES(1),.DETECTOR_LATENCY(1)) owner(
 .clk(clk),.rst(rst),.arm_enable(1'b1),.reset_request(reset_request),.readers_quiescent(1'b1),.quiesce(quiesce),
 .sample_valid(sample_valid),.sample_seq(sample_seq),.primary_trigger(trig),.primary_onset(onset),.primary_pulse_id(pulse),
 .aux_trigger(1'b0),.aux_onset(64'd0),.aux_pulse_id(64'd0),.eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_gen),
 .discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
 .ack_record(1'b0),.ack_record_bank(4'd0),.ack_record_epoch(64'd0),.ack_record_generation(64'd0),
 .ack_replay(1'b0),.ack_replay_bank(4'd0),.ack_replay_epoch(64'd0),.ack_replay_generation(64'd0),
 .write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
 .start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(counts),.owner_epoch(owner_epoch),
 .rejected_returns(),.dropped_triggers(),.primary_admitted(),.aux_admitted());
 reg begin_valid=0,want_replay=1,measurement_valid=0,noise_valid=0,event_ready=0;
 reg [255:0] begin_key=0,measurement_key=0,noise_key=0;
 reg [1023:0] config_data=0;reg [511:0] measurement_data=0;reg [255:0] noise_data=0;
 reg [5:0] bank_ids=0;reg [191:0] bank_generations=0;reg [3071:0] headers=0;
 wire begin_ready,measurement_ready,noise_ready,event_valid,event_published,event_rejected,begin_rejected,measurement_rejected,noise_rejected,idle;
 wire [255:0] event_key;wire [3:0] event_bank;wire [1023:0] event_header;wire [63:0] event_generation,event_epoch;
 reg [3:0] seen;reg [255:0] held_key;
 reg [191:0] measurement_peaks=0;wire [511:0] event_stats;wire [191:0] event_peaks;
 qualification_publish_bridge dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 task prepare;
 begin
  rst=1;tick();rst=0;sample_valid=1;
  for(integer n=0;n<4;n=n+1)begin sample_seq=n;tick();end
  onset=3;sample_seq=4;trig=1;tick();trig=0;
  sample_seq=5;eop_valid=16'h0111;eop_stop={16{64'd6}};eop_gen=generation;tick();sample_valid=0;eop_valid=0;
  check(pending==16'h0111,"three real pending banks");
  bank_ids=0;bank_generations={generation[512+:64],generation[256+:64],generation[0+:64]};
  begin_key={pulse,owner_epoch,generation[0+:64],64'd123};
  config_data=0;
  for(integer c=0;c<6;c=c+1)config_data[c*32+:32]=65536;
  config_data[223:192]=65536;config_data[245:240]=6'b100001;
  config_data[251:246]=63;config_data[257:252]=63;config_data[263:258]=63;
  headers={1024'hccc,1024'hbbb,1024'haaa};
 end endtask
 task send_results;
 begin
  measurement_key=begin_key;noise_key=begin_key;measurement_data=0;noise_data=0;
  for(integer c=0;c<6;c=c+1)begin measurement_data[c*46+:46]=400;noise_data[c*32+:32]=25;end
  measurement_data[290:276]=4;measurement_data[299:297]=7;noise_data[197:192]=63;
  measurement_peaks={6{32'd100+begin_key[31:0]}};
  measurement_valid=1;noise_valid=1;tick();measurement_valid=0;noise_valid=0;
 end endtask
 initial begin
 prepare();begin_valid=1;tick();begin_valid=0;
 // Caller map and header changes after begin may not rewrite this transaction.
 headers=0;bank_generations=0;bank_ids=63;config_data=0;
 send_results();measurement_peaks=0;measurement_data=0;while(!event_valid)tick();
 check(event_published&&!event_rejected&&event_bank==4&&frozen==16'h0010,"actual qualification selected MID and published owner");
 check(event_stats[45:0]==400&&event_peaks[31:0]==223,"retained measurement and peak after source changes");
 check(event_header==1024'hbbb&&event_generation==1&&event_epoch==owner_epoch&&event_key==begin_key,"frozen selected header and generation");
 repeat(5)begin tick();check(event_valid&&event_header==1024'hbbb&&!idle,"event held with map ownership");end
 begin_valid=1;tick();begin_valid=0;check(begin_rejected,"published pending event identity cannot be reused");
 event_ready=1;tick();event_ready=0;#1;check(idle,"bridge drains only after event consumed");
 prepare();bank_generations[127:64]=99;begin_valid=1;tick();begin_valid=0;send_results();while(!event_valid)tick();
 check(event_rejected&&!event_published&&frozen==0&&pending==16'h0111,"stale one-group map rejected without wrong publication");
 event_ready=1;tick();event_ready=0;
 prepare();config_data[262]=0;begin_valid=1;tick();begin_valid=0;send_results();while(!event_valid)tick();
 check(!event_rejected&&!event_published&&pending==0&&frozen==0,"unknown common state valid discard disposition");
 event_ready=1;tick();event_ready=0;
 // Four outstanding maps survive engine retirement and downstream blocking.
 prepare();bank_generations={3{64'd99}};
 for(integer k=0;k<4;k=k+1)begin
  begin_key[63:0]=k;#1;check(begin_ready,"four context admission capacity");
  begin_valid=1;tick();begin_valid=0;
 end
 begin_key[63:0]=4;#1;check(!begin_ready,"fifth map blocked");
 begin_valid=1;tick();begin_valid=0;check(begin_rejected,"full map rejection");
 for(integer k=3;k>=0;k=k-1)begin begin_key[63:0]=k;send_results();end
 while(!event_valid)tick();held_key=event_key;
 reset_request=1;tick();
 repeat(4)begin tick();check(event_valid&&event_key==held_key,"quiesce retains owned event");end
 reset_request=0;tick();seen=0;
 for(integer k=0;k<4;k=k+1)begin
  while(!event_valid)tick();
  check(event_rejected&&!event_published&&event_key[63:0]<4,"each stale map returns disposition");
  check(event_peaks[31:0]==100+event_key[31:0],"out of order peak identity");
  check(!seen[event_key[1:0]],"no duplicate completion");seen[event_key[1:0]]=1;
  event_ready=1;tick();event_ready=0;
 end
 check(seen==15&&idle,"all retained mappings drain exactly once");
 $display("PASS qualification publish bridge real engine owner frozen maps headers stale rejection backpressure invalid discard");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
