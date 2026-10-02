`timescale 1ns/1ps
module tb_capture_producer_tracker;
import calibrator_contract_pkg::*;
reg corrupt_count=0;reg [1023:0] expected_metadata;
reg clk=0;always #4 clk=~clk;
reg rst=1,sample_valid=0;reg [63:0] sample_seq=0;
wire [15:0] write_enable,armed,pending,frozen,truncated,qualified;
wire [1023:0] generation,pulse_id,start_seq;wire [63:0] counts,owner_epoch;wire [63:0] tracker_counts=counts^(corrupt_count?64'h10000:64'd0);
wire primary_trigger,primary_admitted;wire [63:0] primary_onset,primary_pulse;
wire [15:0] eop_valid;wire [1023:0] eop_stop,eop_generation;
capture_bank_manager #(.ADDR_W(3),.PRE_SAMPLES(1),.DETECTOR_LATENCY(1)) owner(
 .analysis_pin(16'd0),.ack_analysis(1'b0),.ack_analysis_bank(4'd0),.ack_analysis_epoch(64'd0),.ack_analysis_generation(64'd0),.analysis_leased(),.record_leased(),

.clk(clk),.rst(rst),.arm_enable(1'b1),.reset_request(1'b0),.readers_quiescent(1'b1),.quiesce(),.sample_valid(sample_valid),.sample_seq(sample_seq),
.primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(primary_pulse),.aux_trigger(1'b0),.aux_onset(64'd0),.aux_pulse_id(64'd0),
.eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),.discard_pending(16'd0),.stats_valid(16'd0),.stats_generation(1024'd0),.stats_good(16'd0),.publish(16'd0),.replay_pin(16'd0),
.ack_record(1'b0),.ack_record_bank(4'd0),.ack_record_epoch(64'd0),.ack_record_generation(64'd0),.ack_replay(1'b0),.ack_replay_bank(4'd0),.ack_replay_epoch(64'd0),.ack_replay_generation(64'd0),
.write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),.start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(counts),.owner_epoch(owner_epoch),.rejected_returns(),.dropped_triggers(),.primary_admitted(primary_admitted),.aux_admitted());
reg onset_want_replay=1;wire request_want_replay,error_bound;
reg block_new_work=0,onset_valid=0,eop_event_valid=0,request_ready=0,error_ready=0;
reg [63:0] onset_seq=3,onset_gsc=12,onset_pulse=77,config_version=9;
reg [1023:0] onset_config=123,onset_metadata=456;reg [255:0] onset_noise=789;reg [5:0] onset_bad=1;
reg [63:0] eop_event_pulse=77,eop_event_epoch=0,eop_event_stop=8;reg [5:0] eop_event_bad=2;
wire onset_ready,onset_accepted,onset_rejected,eop_accepted,eop_rejected,request_valid,error_valid,producers_idle;
wire [255:0] request_key,request_noise,error_key;wire [1023:0] request_config,request_metadata;
wire [5:0] request_bank_ids,request_bad_channels,error_bank_ids;wire [191:0] request_generations,request_starts,error_generations;
wire [44:0] request_counts;wire [63:0] request_onset_seq,request_onset_gsc;
wire [7:0] error_reason;wire [3:0] occupied;wire [31:0] onset_reject_count,eop_reject_count,context_error_count;
capture_producer_tracker #(.ADDR_W(3)) dut(.clk(clk),.rst(rst),.block_new_work(block_new_work),.onset_valid(onset_valid),.onset_ready(onset_ready),.onset_accepted(onset_accepted),.onset_rejected(onset_rejected),
.onset_seq(onset_seq),.onset_gsc(onset_gsc),.onset_pulse_id(onset_pulse),.config_version(config_version),.onset_want_replay(onset_want_replay),.onset_config(onset_config),.onset_noise(onset_noise),.onset_metadata(onset_metadata),.onset_bad_channels(onset_bad),
.primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(primary_pulse),.primary_admitted(primary_admitted),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.generation(generation),.pulse_id(pulse_id),.start_seq(start_seq),.sample_count(tracker_counts),.owner_epoch(owner_epoch),
.eop_event_valid(eop_event_valid),.eop_event_pulse_id(eop_event_pulse),.eop_event_owner_epoch(eop_event_epoch),.eop_event_stop(eop_event_stop),.eop_event_bad_channels(eop_event_bad),.eop_accepted(eop_accepted),.eop_rejected(eop_rejected),.eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),
.request_want_replay(request_want_replay),.request_valid(request_valid),.request_ready(request_ready),.request_key(request_key),.request_config(request_config),.request_noise(request_noise),.request_metadata(request_metadata),.request_bank_ids(request_bank_ids),.request_generations(request_generations),.request_bad_channels(request_bad_channels),.request_starts(request_starts),.request_counts(request_counts),.request_onset_seq(request_onset_seq),.request_onset_gsc(request_onset_gsc),
.error_bound(error_bound),.error_valid(error_valid),.error_ready(error_ready),.error_key(error_key),.error_bank_ids(error_bank_ids),.error_generations(error_generations),.error_reason(error_reason),.occupied(occupied),.producers_idle(producers_idle),.onset_reject_count(onset_reject_count),.eop_reject_count(eop_reject_count),.context_error_count(context_error_count));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
task reset_fixture;
 begin
  corrupt_count=0;onset_valid=0;eop_event_valid=0;request_ready=0;error_ready=0;block_new_work=0;sample_valid=0;
  rst=1;tick();rst=0;sample_valid=1;
  for(integer n=0;n<4;n=n+1)begin sample_seq=n;tick();end
 end
endtask
initial begin
 tick();rst=0;sample_valid=1;for(integer n=0;n<4;n=n+1)begin sample_seq=n;tick();end
 expected_metadata=onset_metadata;
 expected_metadata[FRAME_PULSE_ID_OFFSET*8+:64]=onset_pulse;
 expected_metadata[FRAME_CONFIG_ID_OFFSET*8+:32]=config_version[31:0];
 onset_valid=1;sample_seq=4;tick();onset_valid=0;check(onset_accepted&&!producers_idle,"reserve before actual owner acceptance");
 onset_want_replay=0;onset_config=999;onset_noise=999;onset_metadata=999;config_version=99;onset_bad=63;
 sample_seq=5;eop_event_valid=1;tick();eop_event_valid=0;check(eop_accepted,"real EOP allows future POST exclusive stop");
 block_new_work=1;sample_seq=6;tick();check(eop_valid==16'h0111,"EOP sent once after actual bank bind");sample_seq=7;tick();sample_valid=0;
 for(integer n=0;n<15&&!request_valid;n=n+1)tick();check(request_valid&&!producers_idle,"pending descriptor held during reset drainage");
 check(request_key=={64'd77,64'd0,64'd1,64'd9}&&request_config==123&&request_noise==789&&request_metadata==expected_metadata&&request_want_replay,"onset immutable metadata and full key");
 check(request_bank_ids==0&&request_generations=={64'd1,64'd1,64'd1}&&request_starts=={64'd2,64'd2,64'd2}&&request_counts=={15'd6,15'd6,15'd6},"actual map and post-complete windows");
 check(request_bad_channels==3,"onset and EOP bad flags combined");
 repeat(4)tick();check(request_valid&&occupied==1,"no overwrite under backpressure");
 onset_valid=1;tick();onset_valid=0;check(onset_rejected&&onset_reject_count==1,"blocked onset explicitly rejected");
 eop_event_valid=1;tick();eop_event_valid=0;check(eop_rejected&&eop_reject_count==1,"duplicate EOP refused");
 request_ready=1;tick();request_ready=0;check(producers_idle&&occupied==0,"transfer completes producer ownership only");
 check(pending==16'h0111,"request transfer never frees bank");
 reset_fixture();
 for(integer c=0;c<4;c=c+1)begin
  onset_pulse=100+c;onset_seq=sample_seq;sample_seq=sample_seq+1;onset_valid=1;tick();onset_valid=0;
  sample_seq=sample_seq+1;tick();
 end
 check(occupied==15&&!producers_idle&&!onset_ready,"four producer contexts reserved without overwrite");
 onset_pulse=200;onset_valid=1;sample_seq=sample_seq+1;tick();onset_valid=0;
 check(onset_rejected&&onset_reject_count==1,"fifth onset rejected before owner trigger");
 reset_fixture();onset_seq=0;onset_pulse=201;sample_seq=4;onset_valid=1;tick();onset_valid=0;sample_valid=0;
 repeat(3)tick();check(error_valid&&error_reason==1&&!error_bound&&error_key[127:64]==0&&context_error_count==1&&!producers_idle,"actual owner reject retained for acknowledgement");
 repeat(2)tick();check(error_valid&&error_key[255:192]==201,"error identity held");error_ready=1;tick();error_ready=0;check(producers_idle,"rejected admission releases only after error acknowledgement");
 reset_fixture();onset_seq=3;onset_pulse=202;eop_event_pulse=202;eop_event_stop=5;onset_bad=0;eop_event_bad=0;sample_seq=4;onset_valid=1;eop_event_valid=1;tick();onset_valid=0;eop_event_valid=0;sample_valid=0;
 check(onset_accepted&&eop_accepted,"same-edge short pulse detected EOP preserved");
 for(integer n=0;n<20&&!request_valid;n=n+1)tick();
 check(request_valid&&request_counts=={15'd3,15'd3,15'd3},"short pulse actual window completed");
 reset_fixture();onset_seq=3;onset_pulse=203;onset_bad=0;eop_event_bad=0;sample_seq=4;onset_valid=1;tick();onset_valid=0;
 for(integer n=5;n<=10;n=n+1)begin sample_seq=n;tick();end sample_valid=0;
 for(integer n=0;n<15&&!request_valid;n=n+1)tick();check(request_valid&&request_bad_channels==63,"depth exhausted window marked truncated");request_ready=1;tick();request_ready=0;
 onset_pulse=204;onset_seq=10;sample_seq=11;sample_valid=1;onset_valid=1;tick();onset_valid=0;
 eop_event_pulse=204;eop_event_stop=13;eop_event_valid=1;sample_seq=12;tick();eop_event_valid=0;sample_valid=0;
 for(integer n=0;n<20&&!request_valid;n=n+1)tick();
 check(request_valid&&request_bank_ids==6'b010101&&request_bad_channels==0&&request_key[127:64]==1,"new bank must not inherit old bank truncation during binding");
 reset_fixture();config_version=64'h100000007;onset_pulse=205;onset_seq=3;sample_seq=4;onset_valid=1;tick();onset_valid=0;
 check(onset_rejected&&occupied==0&&!primary_admitted,"ABI5 config high word rejects before owner admission");config_version=7;
 reset_fixture();onset_seq=3;onset_pulse=206;onset_want_replay=1;sample_seq=4;onset_valid=1;tick();onset_valid=0;
 corrupt_count=1;sample_seq=5;eop_event_pulse=206;eop_event_stop=6;eop_event_valid=1;tick();eop_event_valid=0;sample_valid=0;
 for(integer n=0;n<20&&!request_valid&&!error_valid;n=n+1)tick();
 check(request_valid&&!error_valid&&request_bad_channels==63&&!request_want_replay&&context_error_count==1,"valid pending identities with unequal windows drain as all-bad request");
 $display("PASS capture producer tracker: actual owner bind, immutable onset context, detected EOP plus future POST, held drainage");$finish;
end
initial begin #20000;$fatal(1,"timeout");end
endmodule
