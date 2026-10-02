`timescale 1ns/1ps
module tb_capture;
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
 for(i=0;i<4;i=i+1) begin sample(i);end
 @(negedge clk);sample_valid=1;sample_seq=4;#1;if(we!==16'hffff) $fatal(1,"all mutable banks broadcast");sample_valid=0;
 if(armed!==16'hffff) $fatal(1,"rolling broadcast/arming");
 @(negedge clk);trig=1;onset=3;sample_seq=4;sample_valid=1;tick();sample_valid=0;
 if(!admit || starts[0+:64]!=2 || starts[256+:64]!=2 || starts[512+:64]!=2) $fatal(1,"atomic true onset");
 @(negedge clk);trig=0;
 sample(5);sample(6);
 @(negedge clk);eop_valid=16'h111;eop_gen=generations;eop_stop[0+:64]=6;eop_stop[256+:64]=6;eop_stop[512+:64]=6;sample_seq=7;sample_valid=1;tick();sample_valid=0;
 if(pending!==16'h111 || counts[0+:4]!=4 || we[0]) $fatal(1,"late EOP halfopen freeze");
 @(negedge clk);eop_valid=0;sample_valid=0;publish=16'h111;tick();
 if(frozen!=0) $fatal(1,"must wait statistics");
 @(negedge clk);publish=0;stats_valid=16'h111;stats_gen=generations;stats_good=16'h111;tick();
 @(negedge clk);stats_valid=0;publish=16'h111;replay_pin=16'h111;tick();
 if(frozen!==16'h111 || qualified!==16'h111) $fatal(1,"published pin");
 @(negedge clk);publish=0;ack_record=1;ack_record_bank=0;ack_record_epoch=epoch;ack_record_gen=99;tick();
 if(stale!=1 || !frozen[0]) $fatal(1,"stale return");
 @(negedge clk);ack_record_gen=generations[0+:64];tick();
 if(!frozen[0]) $fatal(1,"replay still owns bank");
 tick();if(stale!=2) $fatal(1,"duplicate return");
 @(negedge clk);ack_record=0;ack_replay=1;ack_replay_epoch=epoch;ack_replay_gen=generations[0+:64];tick();
 if(frozen[0]) $fatal(1,"last return rearm");
 @(negedge clk);ack_record=1;ack_record_bank=4;ack_record_gen=generations[256+:64];ack_replay_bank=4;ack_replay_gen=generations[256+:64];tick();
 if(frozen[4]) $fatal(1,"combined same cycle returns");
 @(negedge clk);ack_record=0;ack_replay=0;
 for(i=8;i<12;i=i+1) sample(i);
 @(negedge clk);aux_trig=1;aux_onset=11;sample_seq=12;sample_valid=1;tick();sample_valid=0;
 if(!aux_admit || starts[768+:64]!=10) $fatal(1,"AUX independent onset");
 @(negedge clk);aux_trig=0;
 for(i=13;i<19;i=i+1) sample(i);
 if(!pending[12] || !truncated[12] || counts[48+:4]!=8 || we[12]) $fatal(1,"capacity protects wrap and full count");
 @(negedge clk);reset_request=1;tick();
 if(!quiesce || we!=0) $fatal(1,"reset requests quiescence");
 @(negedge clk);reset_request=0;tick();if(epoch!=0 || !frozen[8]) $fatal(1,"must retain ownership before drain");
 @(negedge clk);readers_quiescent=1;tick();
 if(epoch!=1 || frozen!=0 || armed!=0) $fatal(1,"epoch reset after drained");
 @(negedge clk);reset_request=1;tick();tick();
 if(epoch!=2) $fatal(1,"held reset request advances epoch once");
 @(negedge clk);reset_request=0;sample_valid=0;readers_quiescent=0;
 // Fill four primary bank sets, leaving AUX resources independent.
 for(i=30;i<34;i=i+1) sample(i);
 for(i=0;i<4;i=i+1) begin
 @(negedge clk);trig=1;onset=33+i;sample_seq=34+i;sample_valid=1;tick();sample_valid=0;
 if(!admit) $fatal(1,"four rolling bank admissions");
 end
 @(negedge clk);trig=1;onset=37;aux_trig=1;aux_onset=37;sample_seq=38;sample_valid=1;tick();sample_valid=0;
 if(admit || !aux_admit || drops!=1) $fatal(1,"primary exhausted atomic drop; AUX independent");
 @(negedge clk);trig=0;aux_trig=0;
 // Stale EOP on fresh AUX generation must not prematurely freeze.
 eop_valid=16'h1000;eop_gen[768+:64]=0;eop_stop[768+:64]=38;tick();
 if(pending[12]) $fatal(1,"stale EOP generation must reject");
 @(negedge clk);eop_gen=generations;tick();
 if(!pending[12]) $fatal(1,"current EOP accepted");
 @(negedge clk);eop_valid=0;stats_valid=16'h1000;stats_gen=0;publish=16'h1000;tick();tick();
 if(frozen[12]) $fatal(1,"stale statistics cannot publish");
 @(negedge clk);stats_gen=generations;tick();
 @(negedge clk);stats_valid=0;publish=0;discard_pending=16'h1000;tick();
 if(pending[12] || frozen[12] || armed[12]) $fatal(1,"unselected pending bank rearms fresh");
 @(negedge clk);discard_pending=0;
 for(i=0;i<8;i=i+1) begin @(negedge clk);ena=1;wea=1;aa=i;din=100+i;tick();end
 @(negedge clk);wea=0;aa=7;ab=3;enb=1;tick();@(posedge memclk);#1;
 if(qa!=107 || qb!={64'd107,64'd106}) $fatal(1,"independent A64 B128 packing");
 @(negedge clk);aa=0;ab=0;tick();@(posedge memclk);#1;
 if(qa!=100 || qb!={64'd101,64'd100}) $fatal(1,"RAM wrap origin");
 #1;if(choice_valid) $fatal(1,"unconfigured rank must reject");rank_valid=1;#1;if(!choice_valid||choice!=1) $fatal(1,"calibrated rank");
 order=0;#1;if(choice_valid) $fatal(1,"duplicate gain rank rejects");order=6'b00_10_01;
 hvv=3'b101;#1;if(choice!=2) $fatal(1,"common H/V range");range_done=3'b011;#1;if(choice_valid) $fatal(1,"wait every range");
 range_done=7;range_good=0;#1;if(choice_valid) $fatal(1,"all invalid has no fallback");
 $display("PASS capture: broadcast, atomic admission, onset, pending stats, delayed EOP, capacity, stale/duplicate/combined ACK, reset quiescence, A/B RAM packing, common calibrated range");$finish;
end
endmodule

