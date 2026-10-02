`timescale 1ns/1ps
module tb_capture_reset_hold;
reg clk=0, memclk=0; always #4 clk=~clk; always #2.5 memclk=~memclk;
reg rst=1, reset_request=0, readers_quiescent=0, sample_valid=0;
reg [63:0] sample_seq=0,onset=0,aux_onset=0,pulse_id=7;
reg trig=0,aux_trig=0;
reg [15:0] eop_valid=0,stats_valid=0,publish=0,replay_pin=0;
reg [1023:0] eop_stop=0,stats_gen=0,eop_gen=0;
reg [15:0] discard_pending=0;
reg [15:0] stats_good=0;
reg ack_record=0,ack_replay=0;
reg [3:0] ack_record_bank=0,ack_replay_bank=0;
reg [63:0] ack_record_epoch=0,ack_replay_epoch=0,ack_record_gen=0,ack_replay_gen=0;
wire [15:0] we,armed,pending,frozen,truncated,qualified;
wire [1023:0] starts,generations;
wire [63:0] counts;
wire [63:0] epoch;
wire [31:0] stale,drops;wire quiesce,admit,aux_admit;
capture_bank_manager #(.ADDR_W(3),.PRE_SAMPLES(1),.DETECTOR_LATENCY(1)) dut(
 .analysis_pin(16'd0),.ack_analysis(1'b0),.ack_analysis_bank(4'd0),.ack_analysis_epoch(64'd0),.ack_analysis_generation(64'd0),.analysis_leased(),.record_leased(),

.clk(clk),.rst(rst),.arm_enable(1'b1),.reset_request(reset_request),.readers_quiescent(readers_quiescent),.quiesce(quiesce),
.sample_valid(sample_valid),.sample_seq(sample_seq),.primary_trigger(trig),.primary_onset(onset),.primary_pulse_id(pulse_id),
.aux_trigger(aux_trig),.aux_onset(aux_onset),.aux_pulse_id(pulse_id),
.eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_gen),.discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(stats_gen),.stats_good(stats_good),
.publish(publish),.replay_pin(replay_pin),.ack_record(ack_record),.ack_record_bank(ack_record_bank),.ack_record_epoch(ack_record_epoch),.ack_record_generation(ack_record_gen),
.ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_gen),
.write_enable(we),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),.start_seq(starts),.sample_count(counts),.generation(generations),.owner_epoch(epoch),.rejected_returns(stale),.dropped_triggers(drops),.primary_admitted(admit),.aux_admitted(aux_admit));
reg ena=0,wea=0,enb=0;reg [2:0] aa=0;reg [1:0] ab=0;reg [63:0] din=0;wire [63:0] qa;wire [127:0] qb;
capture_ram #(.ADDR_W(3)) ram(.clka(clk),.ena(ena),.wea(wea),.addra(aa),.dina(din),.douta(qa),.clkb(memclk),.enb(enb),.addrb(ab),.doutb(qb));
reg rank_valid=0;reg [5:0] order=6'b00_10_01;reg [2:0] hvh=7,hvv=7,range_good=7,range_done=7;wire choice_valid;wire [1:0] choice;
capture_range_select sel(.rank_valid(rank_valid),.gain_order(order),.h_valid(hvh),.v_valid(hvv),.context_valid(range_good),.frozen_stats_done(range_done),.selected_valid(choice_valid),.selected_range(choice));
task tick;begin @(posedge clk);#1;end endtask
task sample(input [63:0] n);begin @(negedge clk);sample_seq=n;sample_valid=1;tick();sample_valid=0;end endtask
integer i;
initial begin
 tick();tick();@(negedge clk);rst=0;
 reset_request=1;readers_quiescent=1;tick();
 for(i=0;i<4;i=i+1) begin sample(i); if(we!=0) $fatal(1,"quiesce writes should be off");end
 $display("REPRO held reset: quiesce=%h armed=%h history0=%0d",quiesce,armed,dut.history[0]);
 @(negedge clk);reset_request=0;trig=1;onset=3;sample_seq=4;sample_valid=1;tick();sample_valid=0;
 $display("REPRO held reset: admitted=%h start=%0d count=%0d",admit,starts[0+:64],counts[0+:4]);
 if(admit) $fatal(1,"BUG admitted unwritten history after held reset");
 @(negedge clk);trig=0;readers_quiescent=0;
 if(armed!=0 || epoch!=1) $fatal(1,"held reset must preserve zero history and single epoch advance");
 sample(5);if(armed!=0) $fatal(1,"two stored samples are insufficient history");
 sample(6);if(armed!=16'hffff) $fatal(1,"fresh stored history must rearm");
 @(negedge clk);trig=1;onset=6;sample_seq=7;sample_valid=1;tick();sample_valid=0;
 if(!admit || starts[0+:64]!=5) $fatal(1,"admit only after fresh written history");
 $display("PASS capture held-reset regression: no fictitious history; fresh writes rearm");
 $finish;
end
endmodule
