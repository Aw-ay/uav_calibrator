`timescale 1ns/1ps
module tb_aux_record_pipeline;
 localparam AW=4,PRE=2;
 reg clk=0,rst=1;always #4 clk=~clk;
 reg sample_valid=1,aux_valid=1,block_new_work=0,cancel=0,request_valid=0,result_ready=0;
 reg [63:0] sample_seq=0,sample_gsc=1000,request_onset_seq=0,request_tx_token=64'hfedcba9876543210;
 reg [31:0] request_count=8,source_epoch=7,h_calibration_id=11,v_calibration_id=12,config_id=13,fir_id=14;
 reg [7:0] source_role=3;
 wire request_ready,request_accepted,request_rejected,busy,result_valid,result_bound;
 wire [7:0] result_status,result_source_role;wire [1:0] result_bank;
 wire [63:0] result_capture_id,result_owner_epoch,result_generation,result_start_seq,result_start_gsc,result_tx_token;
 wire [14:0] result_count;wire [31:0] result_source_epoch,result_h_calibration_id,result_v_calibration_id,result_config_id,result_fir_id,reject_count;
 wire aux_trigger,aux_admitted;wire [63:0] aux_onset,aux_pulse_id;
 wire [3:0] aux_eop_valid;wire [255:0] aux_eop_stop,aux_eop_generation;
 reg primary_trigger=0;wire primary_admitted;wire [15:0] write_enable,armed,pending,frozen,truncated,qualified,replay_leased;
 wire [1023:0] start_seq,generation,pulse_id;wire [79:0] sample_count;wire [63:0] owner_epoch;
 wire quiesce;wire [31:0] rejected_returns,dropped_triggers;
 reg reset_request=0;reg [15:0] stats_valid=0,stats_good=65535,publish=0;reg [1023:0] stats_generation=0;
 reg ack_record=0;reg [3:0] ack_record_bank=0;reg [63:0] ack_record_epoch=0,ack_record_generation=0;
 capture_bank_manager #(.ADDR_W(AW),.PRE_SAMPLES(PRE),.DETECTOR_LATENCY(1)) owner(
 .analysis_pin(16'd0),.ack_analysis(1'b0),.ack_analysis_bank(4'd0),.ack_analysis_epoch(64'd0),.ack_analysis_generation(64'd0),.analysis_leased(),.record_leased(),

  .clk(clk),.rst(rst),.arm_enable(1'b1),.reset_request(reset_request),.readers_quiescent(1'b1),.quiesce(quiesce),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.primary_trigger(primary_trigger),.primary_onset(sample_seq),.primary_pulse_id(64'd777),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(aux_pulse_id),.aux_admitted(aux_admitted),.primary_admitted(primary_admitted),
  .eop_valid({aux_eop_valid,12'd0}),.eop_stop({aux_eop_stop,768'd0}),.eop_generation({aux_eop_generation,768'd0}),
  .discard_pending(16'd0),.stats_valid(stats_valid),.stats_generation(stats_generation),.stats_good(stats_good),.publish(publish),.replay_pin(16'd0),
  .ack_record(ack_record),.ack_record_bank(ack_record_bank),.ack_record_epoch(ack_record_epoch),.ack_record_generation(ack_record_generation),
  .ack_replay(1'b0),.ack_replay_bank(4'd0),.ack_replay_epoch(64'd0),.ack_replay_generation(64'd0),
  .write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
  .start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(sample_count),.owner_epoch(owner_epoch),
  .rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.replay_leased(replay_leased));
 aux_window_tracker #(.ADDR_W(AW),.PRE_SAMPLES(PRE)) dut(
  .clk(clk),.rst(rst),.block_new_work(block_new_work),.cancel(cancel),.sample_valid(sample_valid),.sample_seq(sample_seq),.sample_gsc(sample_gsc),
  .aux_valid(aux_valid),.source_role(source_role),.source_epoch(source_epoch),.h_calibration_id(h_calibration_id),.v_calibration_id(v_calibration_id),.config_id(config_id),.fir_id(fir_id),
  .request_valid(request_valid),.request_ready(request_ready),.request_accepted(request_accepted),.request_rejected(request_rejected),
  .request_onset_seq(request_onset_seq),.request_count(request_count),.request_tx_token(request_tx_token),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(aux_pulse_id),.aux_admitted(aux_admitted),
  .armed(armed[15:12]),.pending(pending[15:12]),.frozen(frozen[15:12]),.truncated(truncated[15:12]),
  .generation(generation[768+:256]),.pulse_id(pulse_id[768+:256]),.start_seq(start_seq[768+:256]),.sample_count(sample_count[60+:20]),.owner_epoch(owner_epoch),
  .eop_valid(aux_eop_valid),.eop_stop(aux_eop_stop),.eop_generation(aux_eop_generation),
  .result_valid(result_valid),.result_ready(result_ready),.result_bound(result_bound),.result_status(result_status),.result_bank(result_bank),
  .result_capture_id(result_capture_id),.result_owner_epoch(result_owner_epoch),.result_generation(result_generation),
  .result_start_seq(result_start_seq),.result_start_gsc(result_start_gsc),.result_count(result_count),.result_tx_token(result_tx_token),
  .result_source_role(result_source_role),.result_source_epoch(result_source_epoch),.result_h_calibration_id(result_h_calibration_id),
  .result_v_calibration_id(result_v_calibration_id),.result_config_id(result_config_id),.result_fir_id(result_fir_id),.reject_count(reject_count),.busy(busy));

 reg admit_valid=0,record_ready=0;
 wire admit_ready,record_valid,admit_rejected,capacity_available,id_exhausted;
 wire [31:0] metadata_reject_count;
 wire [1023:0] record_header;wire [767:0] record_metadata;
 wire [59:0] aux_counts;
 for(genvar b=0;b<4;b=b+1)assign aux_counts[b*15+:15]={{(14-AW){1'b0}},sample_count[(12+b)*(AW+1)+:(AW+1)]};
 aux_record_admission adapter(
  .clk(clk),.rst(rst),.request_valid(admit_valid),.result_ready(record_ready),.bound(result_bound),.block_new_work(1'b0),
  .template_header(1024'd0),.epoch_id(32'd9),.source_epoch(result_source_epoch),.h_calibration_id(result_h_calibration_id),
  .v_calibration_id(result_v_calibration_id),.config_id(result_config_id),.fir_id(result_fir_id),.capture_id(result_capture_id),
  .owner_epoch(result_owner_epoch),.generation(result_generation),.tx_token(result_tx_token),.start_seq(result_start_seq),.start_gsc(result_start_gsc),
  .requested_count(result_count),.source_role(result_source_role),.status(result_status),.bank({2'd0,result_bank}),
  .live_owner_epoch(owner_epoch),.pending(pending[15:12]),.frozen(frozen[15:12]),.truncated(truncated[15:12]),
  .bank_generation(generation[768+:256]),.bank_capture_id(pulse_id[768+:256]),.bank_start_seq(start_seq[768+:256]),.bank_sample_count(aux_counts),
  .request_ready(admit_ready),.result_valid(record_valid),.rejected(admit_rejected),.capacity_available(capacity_available),
  .id_exhausted(id_exhausted),.reject_count(metadata_reject_count),.header_data(record_header),.metadata_data(record_metadata));
 reg [63:0] memory[0:15][0:15];integer writes[0:15];
 always @(posedge clk)if(!rst)for(integer n=0;n<16;n=n+1)if(write_enable[n])begin memory[n][sample_seq%16]<=sample_seq;writes[n]<=writes[n]+1;end
 task tick;begin @(posedge clk);#1;@(negedge clk);sample_seq=sample_seq+1;sample_gsc=sample_gsc+4;end endtask
 task submit(input bit okay);begin request_onset_seq=sample_seq;request_valid=1;tick();request_valid=0;if(request_accepted!==okay||request_rejected===okay)$fatal(1,"request acceptance");end endtask
 task finish_window(input [7:0] status);begin
  for(integer n=0;n<25&&!result_valid;n=n+1)tick();
  if(!result_valid||!result_bound||result_status!=status)$fatal(1,"result status expected=%h got=%h bound=%b",status,result_status,result_bound);
 end endtask
 task freeze_result;integer bank;begin
  bank=12+result_bank;
  admit_valid=1;tick();admit_valid=0;
  if(!record_valid||admit_rejected||record_header[64*8+:32]!=sample_count[bank*(AW+1)+:(AW+1)]||record_metadata[84*8+:32]!=sample_count[bank*(AW+1)+:(AW+1)]||record_metadata[40*8+:64]!=result_tx_token)$fatal(1,"real bank actual record length/identity");
  if(result_status[4] && record_header[64*8+:32]>=result_count)$fatal(1,"truncation fabricated samples");
  record_ready=1;tick();record_ready=0;
  stats_generation[bank*64+:64]=result_generation;stats_valid[bank]=1;tick();stats_valid=0;publish[bank]=1;tick();publish=0;
  if(!frozen[bank]||replay_leased[bank])$fatal(1,"bad independent publish ownership");result_ready=1;tick();result_ready=0;
 end endtask
 reg [63:0] expected_start,expected_gsc;reg [511:0] held;integer old_writes;
 initial begin
  for(integer n=0;n<16;n=n+1)writes[n]=0;
  tick();rst=0;submit(0);repeat(10)tick();
  block_new_work=1;submit(0);block_new_work=0;
  aux_valid=0;tick();aux_valid=1;submit(0);repeat(4)tick();
  request_count=4;submit(0);request_count=8;
  request_onset_seq=sample_seq+1;request_valid=1;tick();request_valid=0;if(!request_rejected)$fatal(1,"future request moved");
  request_count=0;submit(0);request_count=17;submit(0);request_count=8;
  request_onset_seq=sample_seq-1;request_valid=1;tick();request_valid=0;if(!request_rejected)$fatal(1,"late request moved");
  primary_trigger=1;expected_start=sample_seq-PRE;expected_gsc=sample_gsc-4*PRE;submit(1);primary_trigger=0;
  if(!primary_admitted||!aux_admitted)$fatal(1,"simultaneous main AUX admission");
  finish_window(0);
  if(result_capture_id!=1||result_bank!=0||result_start_seq!=expected_start||result_start_gsc!=expected_gsc||result_count!=8||result_tx_token!=64'hfedcba9876543210||result_source_epoch!=7||result_h_calibration_id!=11||result_v_calibration_id!=12||result_config_id!=13||result_fir_id!=14||result_source_role!=3)$fatal(1,"frozen identity");
  for(integer n=0;n<8;n=n+1)if(memory[12][(expected_start+n)%16]!=expected_start+n)$fatal(1,"actual write window");
  held={result_capture_id,result_owner_epoch,result_generation,result_start_seq,result_start_gsc,result_tx_token,112'd0,result_count,result_bound};old_writes=writes[12];
  repeat(20)begin tick();if(held!={result_capture_id,result_owner_epoch,result_generation,result_start_seq,result_start_gsc,result_tx_token,112'd0,result_count,result_bound}||writes[12]!=old_writes||result_status!=0)$fatal(1,"held result or RAW overwritten");end
  submit(0);freeze_result();
  submit(1);source_epoch=8;finish_window(1);if(result_source_epoch!=7)$fatal(1,"source identity not frozen");freeze_result();repeat(4)tick();
  submit(1);aux_valid=0;finish_window(2);freeze_result();aux_valid=1;repeat(5)tick();
  submit(1);cancel=1;tick();cancel=0;finish_window(4);freeze_result();
  submit(0);if(armed[15:12]!=0||(|replay_leased))$fatal(1,"AUX capacity/replay isolation");
  for(integer n=12;n<16;n=n+1)begin ack_record_bank=n;ack_record_epoch=owner_epoch;ack_record_generation=generation[n*64+:64];ack_record=1;tick();ack_record=0;end
  repeat(6)tick();request_count=16;submit(1);finish_window(0);if(result_count!=16)$fatal(1,"full bank count wrapped");freeze_result();
  repeat(4)tick();request_count=8;submit(1);tick();sample_seq=sample_seq+2;sample_gsc=sample_gsc+8;
  finish_window(18);freeze_result();
  repeat(4)tick();request_count=8;submit(1);reset_request=1;tick();reset_request=0;tick();
  if(!result_valid||result_bound||!(result_status&8))$fatal(1,"owner epoch reset not detected");
  $display("PASS AUX_PIPELINE actual owner/tracker/record adapter, truncated retained length, full identities and main coexistence");$finish;
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
