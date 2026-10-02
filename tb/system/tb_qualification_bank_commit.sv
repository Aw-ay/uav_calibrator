`timescale 1ns/1ps
module tb_qualification_bank_commit;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,reset_request=0,sample_valid=0,trig=0;
 reg [63:0] sample_seq=0,onset=0,pulse=77;
 reg [15:0] eop_valid=0;reg [1023:0] eop_stop=0,eop_gen=0;
 wire [15:0] write_enable,armed,pending,frozen,truncated,qualified;
 wire [1023:0] generation,pulse_id,start_seq;wire [63:0] counts,owner_epoch;
 wire [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending;
 wire [1023:0] stats_generation;wire quiesce;
 capture_bank_manager #(.ADDR_W(3),.PRE_SAMPLES(1),.DETECTOR_LATENCY(1)) owner(
 .analysis_pin(16'd0),.ack_analysis(1'b0),.ack_analysis_bank(4'd0),.ack_analysis_epoch(64'd0),.ack_analysis_generation(64'd0),.analysis_leased(),.record_leased(),

 .clk(clk),.rst(rst),.arm_enable(1'b1),.reset_request(reset_request),.readers_quiescent(1'b1),.quiesce(quiesce),
 .sample_valid(sample_valid),.sample_seq(sample_seq),.primary_trigger(trig),.primary_onset(onset),.primary_pulse_id(pulse),
 .aux_trigger(1'b0),.aux_onset(64'd0),.aux_pulse_id(64'd0),.eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_gen),
 .discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
 .ack_record(1'b0),.ack_record_bank(4'd0),.ack_record_epoch(64'd0),.ack_record_generation(64'd0),
 .ack_replay(1'b0),.ack_replay_bank(4'd0),.ack_replay_epoch(64'd0),.ack_replay_generation(64'd0),
 .write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
 .start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(counts),.owner_epoch(owner_epoch),
 .rejected_returns(),.dropped_triggers(),.primary_admitted(),.aux_admitted());
 reg request_valid=0,selected_valid=1,want_replay=1;
 reg [1:0] selected_range=1;reg [5:0] channel_qualified=63,bank_ids=0;
 reg [63:0] expected_epoch=0,expected_pulse=77;reg [191:0] expected_generations=0;
 wire request_ready,busy,done,rejected,published;wire [3:0] published_bank;
 qualification_bank_commit dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 task prepare;
 begin
  rst=1;tick();rst=0;sample_valid=1;
  for(integer n=0;n<4;n=n+1)begin sample_seq=n;tick();end
  onset=3;sample_seq=4;trig=1;tick();trig=0;
  sample_seq=5;eop_valid=16'h0111;eop_stop={16{64'd6}};eop_gen=generation;tick();
  sample_valid=0;eop_valid=0;check(pending==16'h0111,"actual three-group capture frozen pending");
  expected_epoch=owner_epoch;expected_pulse=pulse;bank_ids=0;
  expected_generations={generation[512+:64],generation[256+:64],generation[0+:64]};
 end endtask
 initial begin
 prepare();expected_generations[127:64]=99;request_valid=1;tick();request_valid=0;
 check(rejected&&!busy&&frozen==0,"one stale group rejects atomic transaction");
 expected_generations={generation[512+:64],generation[256+:64],generation[0+:64]};
 expected_epoch=owner_epoch+1;request_valid=1;tick();request_valid=0;check(rejected&&pending==16'h0111,"stale epoch leaves banks pending");expected_epoch=owner_epoch;
 expected_pulse=pulse+1;request_valid=1;tick();request_valid=0;check(rejected,"wrong pulse rejected");expected_pulse=pulse;
 request_valid=1;tick();request_valid=0;check(busy&&frozen==0,"admit does not publish early");
 tick();check(frozen==0&&qualified==16'h0111,"statistics visible before publish");
 check(publish==16'h0010&&replay_pin==16'h0010&&discard_pending==16'h0101,"atomic lease and normal policy controls");
 tick();check(done&&published&&published_bank==4&&frozen==16'h0010&&pending==0,"only selected MID published, other groups discarded");
 request_valid=1;tick();request_valid=0;check(rejected,"duplicate commit rejected");
 prepare();selected_valid=0;request_valid=1;tick();request_valid=0;tick();tick();
 check(done&&!published&&frozen==0&&pending==0,"all invalid discarded, no default LOW");
 prepare();selected_valid=1;channel_qualified=0;request_valid=1;tick();request_valid=0;tick();tick();
 check(done&&!published&&frozen==0&&pending==0,"selection flag cannot bypass failed HV qualification");channel_qualified=63;
 prepare();selected_valid=1;request_valid=1;tick();request_valid=0;reset_request=1;tick();reset_request=0;tick();
 check(frozen==0&&!published&&!busy,"owner quiesce cancels without publishing");
 $display("PASS qualification bank commit actual owner atomic identity stats-before-publish selected discard invalid reset");$finish;
 end
 initial begin #10000;$fatal(1,"watchdog");end
endmodule
