`timescale 1ns/1ps
module tb_fine_bank_ownership;
 reg clk=0,rst=1;always #4 clk=~clk;
 reg [63:0] sample_seq=0;reg sample_valid=0,primary_trigger=0;
 reg [15:0] eop_valid=0,stats_valid=0,publish=0,discard_pending=0,analysis_pin=0;
 wire [1023:0] generation;wire [15:0] frozen,pending,analysis_leased,record_leased,replay_leased;
 wire [63:0] owner_epoch;wire [31:0] rejected_returns;
 reg ack_record=0,ack_replay=0,ack_analysis=0;reg [3:0] ack_analysis_bank=0;
 reg [63:0] ack_analysis_epoch=0,ack_analysis_generation=0;
 reg reset_request=0,readers_quiescent=0;
 capture_bank_manager #(.PRE_SAMPLES(1),.DETECTOR_LATENCY(1),.ENABLE_FINE(1)) dut(
  .clk(clk),.rst(rst),.arm_enable(1'b1),.reset_request(reset_request),.readers_quiescent(readers_quiescent),.quiesce(),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.primary_trigger(primary_trigger),.primary_onset(64'd3),.primary_pulse_id(64'd11),
  .aux_trigger(1'b0),.aux_onset(64'd0),.aux_pulse_id(64'd0),.eop_valid(eop_valid),.eop_stop({16{64'd6}}),.eop_generation(generation),
  .discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(generation),.stats_good(16'h111),.publish(publish),.replay_pin(16'h1),
  .analysis_pin(analysis_pin),.analysis_leased(analysis_leased),.record_leased(record_leased),.replay_leased(replay_leased),
  .ack_record(ack_record),.ack_record_bank(4'd0),.ack_record_epoch(owner_epoch),.ack_record_generation(generation[63:0]),
  .ack_replay(ack_replay),.ack_replay_bank(4'd0),.ack_replay_epoch(owner_epoch),.ack_replay_generation(generation[63:0]),
  .ack_analysis(ack_analysis),.ack_analysis_bank(ack_analysis_bank),.ack_analysis_epoch(ack_analysis_epoch),.ack_analysis_generation(ack_analysis_generation),
  .frozen(frozen),.pending(pending),.generation(generation),.owner_epoch(owner_epoch),.rejected_returns(rejected_returns),
  .write_enable(),.armed(),.truncated(),.qualified(),.start_seq(),.pulse_id(),.sample_count(),.dropped_triggers(),.primary_admitted(),.aux_admitted());
 task automatic step;begin @(negedge clk);#0.1;end endtask
 initial begin
  repeat(3)step();rst=0;sample_valid=1;for(integer n=0;n<4;n=n+1)begin sample_seq=n;step();end
  sample_seq=4;primary_trigger=1;step();primary_trigger=0;sample_seq=5;step();sample_valid=0;eop_valid=16'h111;step();eop_valid=0;
  if(pending!=16'h111)$fatal(1,"pending");stats_valid=16'h111;step();stats_valid=0;
  publish=1;discard_pending=16'h110;analysis_pin=16'h111;step();publish=0;discard_pending=0;analysis_pin=0;
  if(frozen!=16'h111||analysis_leased!=16'h111||record_leased!=1||replay_leased!=1)$fatal(1,"atomic three refs and unselected analysis-only banks");
  ack_record=1;ack_replay=1;step();ack_record=0;ack_replay=0;
  if(!frozen[0]||record_leased!=0||replay_leased!=0)$fatal(1,"analysis not retained");
  ack_analysis=1;ack_analysis_generation=generation[63:0]+1;step();
  if(rejected_returns!=1||!frozen[0])$fatal(1,"stale generation");
  ack_analysis_generation=generation[63:0];ack_analysis_epoch=1;step();
  if(rejected_returns!=2||!frozen[0])$fatal(1,"stale epoch");
  ack_analysis_epoch=0;step();if(frozen[0])$fatal(1,"last reference");
  step();if(rejected_returns!=3)$fatal(1,"duplicate analysis ack");ack_analysis=0;
  reset_request=1;step();reset_request=0;repeat(5)step();if(owner_epoch!=0||analysis_leased!=16'h110)$fatal(1,"reset before drain");
  readers_quiescent=1;step();if(owner_epoch!=1||analysis_leased!=0||frozen!=0)$fatal(1,"coordinated drain");
  // All six independent completion orders. Owner must tolerate any integration policy.
  for(integer order=0;order<6;order=order+1)begin
   rst=1;reset_request=0;readers_quiescent=0;ack_analysis=0;ack_record=0;ack_replay=0;step();rst=0;
   sample_valid=1;for(integer n=0;n<4;n=n+1)begin sample_seq=n;step();end
   sample_seq=4;primary_trigger=1;step();primary_trigger=0;sample_seq=5;step();sample_valid=0;eop_valid=16'h111;step();eop_valid=0;
   stats_valid=16'h111;step();stats_valid=0;publish=1;discard_pending=16'h110;analysis_pin=1;step();publish=0;discard_pending=0;analysis_pin=0;
   ack_analysis_bank=0;ack_analysis_epoch=0;ack_analysis_generation=generation[63:0];
   for(integer phase=0;phase<3;phase=phase+1)begin : ordered_ack
    integer which;
    case(order)
     0:which=phase;
     1:which=phase==0?0:(phase==1?2:1);
     2:which=phase==0?1:(phase==1?0:2);
     3:which=phase==0?1:(phase==1?2:0);
     4:which=phase==0?2:(phase==1?0:1);
     default:which=2-phase;
    endcase
    ack_record=which==0;ack_replay=which==1;ack_analysis=which==2;step();
    if(frozen[0]!=(phase!=2))$fatal(1,"six-order reference release order=%0d phase=%0d",order,phase);
   end
  end
  $display("PASS Fine bank ownership: atomic analysis pin on selected/discarded ranges, all six completion orders, three independent references, exact epoch/generation, duplicate rejection and reset drainage");$finish;
 end
 initial begin #10000;$fatal(1,"timeout");end
endmodule
