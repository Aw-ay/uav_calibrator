`timescale 1ns/1ps
module tb_capture_statistics_reader;
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

 assign stats_valid=0;assign stats_good=0;assign publish=0;assign replay_pin=0;assign discard_pending=0;assign stats_generation=0;
 reg [63:0] onset_base=3;reg [15:0] force_truncated=0;
 reg request_valid=0,result_ready=0,abort_request=0,corrupt_gen=0,corrupt_count=0;
 reg [5:0] request_bank_ids=0,request_bad_channels=0;
 reg [191:0] request_generations=0;reg [255:0] request_key=0;
 wire request_ready,busy,result_valid;wire [255:0] result_key;wire [511:0] result_stats;
 wire [191:0] result_peaks,result_generations;wire [5:0] result_bank_ids;wire [7:0] result_error;
 wire [15:0] ram_read_enable;wire [47:0] ram_read_address;wire [1023:0] ram_read_data;
 reg [15:0] read_valid=0,drop_mask=0;wire [15:0] ram_read_valid=read_valid&~drop_mask;
 wire [1023:0] live_gen=generation ^ (corrupt_gen?1024'd1:1024'd0);
 wire [63:0] live_counts=counts ^ (corrupt_count?64'h10000:64'd0);
 capture_statistics_reader #(.ADDR_W(3)) dut(.clk(clk),.rst(rst),.request_valid(request_valid),.request_ready(request_ready),.request_bank_ids(request_bank_ids),.request_generations(request_generations),.request_key(request_key),.request_bad_channels(request_bad_channels),.pending(pending),.frozen(frozen),.truncated(truncated|force_truncated),.generation(live_gen),.pulse_id(pulse_id),.start_seq(start_seq),.sample_count(live_counts),.owner_epoch(owner_epoch),.abort_request(abort_request),.ram_read_enable(ram_read_enable),.ram_read_address(ram_read_address),.ram_read_data(ram_read_data),.ram_read_valid(ram_read_valid),.busy(busy),.result_valid(result_valid),.result_ready(result_ready),.result_key(result_key),.result_stats(result_stats),.result_peaks(result_peaks),.result_bank_ids(result_bank_ids),.result_generations(result_generations),.result_error(result_error));
 function automatic [63:0] sample_word(input integer seq,input integer group_n);
 reg signed [15:0] hi,vi;
 begin hi=(seq+1)*(group_n+1);vi=-(seq+2)*(group_n+1);sample_word={16'd0,vi,16'd0,hi};end
 endfunction
 genvar b;generate for(b=0;b<16;b=b+1)begin: banks
  wire [2:0] address=write_enable[b]?sample_seq[2:0]:ram_read_address[b*3+:3];
  capture_ram #(.ADDR_W(3)) ram(.clka(clk),.ena(write_enable[b]||ram_read_enable[b]),.wea(write_enable[b]),.addra(address),.dina(sample_word(sample_seq,b/4)),.douta(ram_read_data[b*64+:64]),.clkb(clk),.enb(1'b0),.addrb(2'd0),.doutb());
 end endgenerate
 always @(posedge clk)begin
  if(rst)read_valid<=0;else read_valid<=ram_read_enable;
  if(!rst && |(ram_read_enable&write_enable))$fatal(1,"RAM port conflict");
  if(!rst && |(ram_read_enable&~pending))$fatal(1,"read outside PENDING");
 end
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 task prepare;
 begin
  request_valid=0;result_ready=0;abort_request=0;corrupt_gen=0;corrupt_count=0;drop_mask=0;request_bad_channels=0;force_truncated=0;
  rst=1;tick();rst=0;sample_valid=1;
  for(integer n=0;n<onset_base+1;n=n+1)begin sample_seq=n;tick();end
  onset=onset_base;sample_seq=onset_base+1;trig=1;tick();trig=0;
  sample_seq=onset_base+2;eop_valid=16'h0111;eop_stop={16{onset_base+64'd3}};eop_gen=generation;tick();
  sample_valid=0;eop_valid=0;check(pending==16'h0111,"real owner PENDING capture");
  request_generations={generation[512+:64],generation[256+:64],generation[0+:64]};
  request_key={pulse,owner_epoch,64'd42,64'd19};request_bank_ids=0;
 end endtask
 task start_scan;begin request_valid=1;tick();request_valid=0;end endtask
 task finish_scan;begin for(integer t=0;t<40&&!result_valid;t=t+1)tick();check(result_valid,"bounded result latency");end endtask
 initial begin
  prepare();start_scan();finish_scan();check(result_error==0&&result_stats[290:276]==4&&result_stats[299:297]==7,"full count and done");
  for(integer g=0;g<3;g=g+1)begin
   check(result_stats[g*46+:46]==86*(g+1)*(g+1),"H energy includes pre-trigger samples");
   check(result_stats[(g+3)*46+:46]==126*(g+1)*(g+1),"V signed energy includes pre-trigger samples");
   check(result_peaks[g*32+:32]==36*(g+1)*(g+1)&&result_peaks[(g+3)*32+:32]==49*(g+1)*(g+1),"six peak powers");
  end
  check(result_key==request_key&&result_generations==request_generations&&result_bank_ids==0,"full key and actual per-group generations retained");
  repeat(3)tick();check(result_valid&&result_stats[275:0]!=0&&ram_read_enable==0,"held result no further reads");result_ready=1;tick();check(!result_valid&&request_ready,"result retirement");
  prepare();request_bad_channels=6'b100001;start_scan();finish_scan();check(result_error==0&&result_stats[296:291]==6'b100001,"latched external bad flags");
  prepare();drop_mask=16'h0010;start_scan();finish_scan();check(result_error==3&&result_stats[299:297]==0&&result_stats[290:276]==0,"missing real RAM response fails closed");
  prepare();start_scan();tick();corrupt_gen=1;finish_scan();check(result_error==1&&ram_read_enable==0,"generation change aborts ongoing scan");
  prepare();corrupt_count=1;start_scan();finish_scan();check(result_error==2&&ram_read_enable==0,"unequal windows rejected without reads");
  prepare();start_scan();abort_request=1;finish_scan();check(result_error==4&&ram_read_enable==0,"explicit abort drains request");
  onset_base=8;prepare();start_scan();finish_scan();check(result_error==0&&result_stats[45:0]==366&&result_stats[3*46+:46]==446,"ring-address wrap full-window sums");onset_base=3;
  prepare();force_truncated=16'h0010;start_scan();finish_scan();check(result_error==0&&result_stats[296:291]==6'b010010,"truncated group invalidates both H/V only");
  prepare();request_key[255:192]=pulse+1;start_scan();finish_scan();check(result_error==1,"wrong pulse cannot read actual banks");
  prepare();request_key[191:128]=owner_epoch+1;start_scan();finish_scan();check(result_error==1,"wrong epoch cannot read actual banks");
  $display("PASS capture statistics reader: real owner/RAM full-window six-channel statistics, identity and missing-response aborts");$finish;
 end
 initial begin #30000;$fatal(1,"timeout");end
endmodule
