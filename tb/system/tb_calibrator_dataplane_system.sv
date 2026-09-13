`timescale 1ns/1ps
module tb_calibrator_dataplane_system #(parameter CANCEL_ONLY=0);
 import replay_control_layout_pkg::*;
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
 wire bridge_idle=dut.capture.backend.bridge_idle;
 wire producer_error_valid;wire [7:0] producer_error_reason;wire onset_ready;

 reg [63:0] gsc=0;always @(posedge rf)if(!rst_n)gsc<=0;else gsc<=gsc+4;
 reg binding_valid=0,tx_request=0,tx_cfg=0,tx_mode=0,profile_commit=0,submit_valid=0;
 reg [1535:0] task_data=0;reg [143:0] matrix=0;
 reg pa_fb=0,tr_fb=0,protect_fb=1;
 always @(negedge rf)begin pa_fb=pa_req;tr_fb=tr_req;protect_fb=protect_req;end
 wire permit,pipe_ready,pa_req,tr_req,protect_req,submit_ok,rejected,token_valid,dsp_done;
 wire [2:0] mode;wire [63:0] raw_data,out_hv;wire raw_valid,out_valid,out_qualified;
 wire [15:0] leased;wire [1023:0] dac_data;wire [31:0] rejected_tokens;
 reg saw_tx_sample=0,saw_dac_output=0;
 integer raw_count=0,dsp_count=0;reg check_replay=0;reg [63:0] expected_replay;
 always @(posedge rf)begin #1;
  if(!binding_valid&&dac_data!==0)$fatal(1,"UNBOUND output");
  if(mode==2&&dut.t_calibrated_valid[0]&&dut.t_calibrated_i[15:0]==16381&&dut.t_calibrated_q[15:0]==1)saw_tx_sample=1;
  if(mode==2&&dac_data!=0)saw_dac_output=1;
  if(raw_valid)begin
   if(raw_data!=={16'hffff,16'(16382+raw_count),16'd1,16'(16381+raw_count)})$fatal(1,"shared RAW RAM sample %0d",raw_count);
   raw_count=raw_count+1;
  end
  if(check_replay&&out_valid)begin
   expected_replay=(dsp_count>=31&&dsp_count<38)?{16'hffff,16'(16382+dsp_count-31),16'd1,16'(16381+dsp_count-31)}:64'd0;
   if(!out_qualified||out_hv!==expected_replay)$fatal(1,"shared RAM DSP result %0d %h %h",dsp_count,out_hv,expected_replay);
   dsp_count=dsp_count+1;
  end
 end
 calibrator_dataplane_system #(.PRE_SAMPLES(3),.DETECTOR_LATENCY(1),.FIFO_ADDR_W(2),.AWG_DEPTH(128)) dut(
 .replay_leased(leased),
 .clk_rf(rf),
 .clk_mem(mem),
 .rst_n(rst_n),
 .arm_enable(1'b1),
 .reset_request(reset_request),
 .sample_valid(sample_valid),
 .sample_seq(sample_seq),
 .group_data(group_data),
 .onset_valid(primary_trigger),
 .onset_ready(onset_ready),
 .onset_accepted(),
 .onset_rejected(),
 .onset_seq(primary_onset),
 .onset_gsc(64'd65536),
 .onset_pulse_id(64'd100),
 .config_version(64'd7),
 .onset_config(config_data),
 .onset_metadata(h[0]),
 .onset_noise(noise_data),
 .onset_bad_channels(6'd0),
 .onset_want_replay(1'b1),
 .eop_event_valid(eop_valid[0]),
 .eop_event_pulse_id(64'd100),
 .eop_event_owner_epoch(64'd0),
 .eop_event_stop(64'd16388),
 .eop_event_bad_channels(6'd0),
 .eop_accepted(),
 .eop_rejected(),
 .producer_error_valid(producer_error_valid),
 .producer_error_bound(),
 .producer_error_ready(1'b0),
 .producer_error_key(),
 .producer_error_bank_ids(),
 .producer_error_generations(),
 .producer_error_reason(producer_error_reason),
 .onset_reject_count(),
 .eop_reject_count(),
 .context_error_count(),
 .header_error(),
 .statistics_error(statistics_error),
 .disposition_valid(disposition_valid),
 .descriptor_accepted(descriptor_accepted),
 .disposition_rejected(disposition_rejected),
 .completion_valid(completion_valid),
 .completion_error(completion_error),
 .completion_epoch(completion_epoch),
 .completion_generation(completion_generation),
 .completion_group(completion_group),
 .completion_bank(completion_bank),
 .record_errors(record_errors),
 .rejected_returns(rejected_returns),
 .dropped_triggers(dropped_triggers),
 .write_enable(write_enable),
 .armed(armed),
 .pending(pending),
 .frozen(frozen),
 .truncated(truncated),
 .qualified(qualified),
 .start_seq(start_seq),
 .generation(generation),
 .pulse_id(pulse_id),
 .sample_count(sample_count),
 .owner_epoch(owner_epoch),
 .quiesce(quiesce),
 .idle_rf(idle_rf),
 .primary_admitted(),
 .block_new_work(block_new_work),
 .reset_busy(reset_busy),
 .reset_done(reset_done),
 .m_axis_tdata(md),
 .m_axis_tkeep(mk),
 .m_axis_tlast(ml),
 .m_axis_tvalid(mv),
 .m_axis_tready(mr),
 .fifo_occupancy(occupancy),
 .r_submit_valid(submit_valid),
 .r_submit_task(task_data),
 .r_submit_accepted(submit_ok),
 .r_submit_rejected(),
 .r_submit_reason(),
 .r_lookup_valid(),
 .r_lookup_task(),
 .r_current_config_id(32'd7),
 .r_current_fir_id(32'd12),
 .r_current_source_epoch(32'd13),
 .r_source_stable(1'b1),
 .r_allow_aux_replay('0),
 .r_task_profiles_valid(1'b1),
 .r_guard_clear(1'b1),
 .r_planned_slot_clear(1'b1),
 .r_resources_ready(1'b1),
 .r_time_valid(1'b1),
 .r_clock_ok(1'b1),
 .r_latency_validated(1'b1),
 .r_fractional_supported('0),
 .r_downstream_latency_ticks(64'd168),
 .r_rejected_valid(rejected),
 .r_rejected_task(),
 .r_reject_reason(),
 .r_reject_ready(1'b1),
 .r_task_started(),
 .r_active_task(),
 .r_raw_valid(raw_valid),
 .r_raw_data(raw_data),
 .r_raw_last(),
 .r_ram_en(),
 .r_ram_addr(),
 .r_ram_group(),
 .r_ram_bank(),
 .r_actual_start(),
 .r_actual_finish(),
 .r_actual_start_gsc(),
 .r_actual_finish_gsc(),
 .r_token_valid(token_valid),
 .r_token_owner_epoch(),
 .r_token_generation(),
 .r_token_group(),
 .r_token_bank(),
 .r_token_consumer(),
 .r_token_status(),
 .r_queued_count(),
 .r_idle(),
 .r_profile_commit(profile_commit),
 .r_shadow_cal_valid(2'b11),
 .r_shadow_dc('0),
 .r_shadow_gain({18'd0,18'd65536,18'd0,18'd65536}),
 .r_shadow_matrix(matrix),
 .r_shadow_fd_phase('0),
 .r_shadow_fd_version(32'h9d1dc12a),
 .r_shadow_rx_cal_id(32'd101),
 .r_shadow_target_matrix_id(32'd102),
 .r_shadow_doppler_phase_id(32'd103),
 .r_phase_valid(1'b1),
 .r_phase_i(18'd65536),
 .r_phase_q('0),
 .r_profile_ready(),
 .r_profile_accepted(),
 .r_profile_rejected(),
 .r_source_ready(),
 .r_dsp_busy(),
 .r_dsp_done(dsp_done),
 .r_dsp_cancelled(),
 .r_out_hv(out_hv),
 .r_out_valid(out_valid),
 .r_out_qualified(out_qualified),
 .r_arithmetic_saturated(),
 .r_table_version(),
 .r_active_rx_cal_id(),
 .r_active_target_matrix_id(),
 .r_active_doppler_phase_id(),
 .r_active_fd_version(),
 .r_active_fd_phase(),
 .t_binding_valid(binding_valid),
 .t_timing_valid(1'b1),
 .t_arm(1'b1),
 .t_tx_request(tx_request),
 .t_hard_fault('0),
 .t_pll_locked(1'b1),
 .t_heartbeat(1'b1),
 .t_clear_fault('0),
 .t_pa_on_fb(pa_fb),
 .t_tr_tx_fb(tr_fb),
 .t_rx_protected_fb(protect_fb),
 .t_protect_cycles('0),
 .t_switch_cycles('0),
 .t_pa_cycles('0),
 .t_recovery_cycles('0),
 .t_transition_timeout_cycles(32'd100),
 .t_watchdog_cycles(32'd1000),
 .t_pa_enable_req(pa_req),
 .t_tr_tx_req(tr_req),
 .t_rx_protect_req(protect_req),
 .t_rf_dac_mute(),
 .t_rf_fault(),
 .t_unbound(),
 .t_rf_permit(permit),
 .t_rf_state(),
 .t_stop_request('0),
 .t_safe_boundary(1'b1),
 .t_mode_request(tx_mode),
 .t_config_commit(tx_cfg),
 .t_single_antenna_ota('0),
 .t_requested_mode(3'd2),
 .t_route_select('0),
 .t_route_enable(8'hff),
 .t_cal_valid(8'hff),
 .t_dc_i('0),
 .t_dc_q('0),
 .t_gain_i({8{18'd65536}}),
 .t_gain_q('0),
 .t_config_id(32'd7),
 .t_dds_cmd_valid('0),
 .t_dds_start_gsc('0),
 .t_dds_pw_samples('0),
 .t_dds_pri_samples('0),
 .t_dds_pulse_count('0),
 .t_dds_initial_pinc('0),
 .t_dds_chirp_step('0),
 .t_dds_reset_each_pulse('0),
 .t_dds_accepted(),
 .t_dds_rejected(),
 .t_dds_busy(),
 .t_dds_done(),
 .t_awg_ctrl_valid('0),
 .t_awg_ctrl_op('0),
 .t_awg_ctrl_length('0),
 .t_awg_ctrl_crc32c('0),
 .t_awg_ctrl_data('0),
 .t_awg_ctrl_ready(),
 .t_awg_ctrl_done(),
 .t_awg_ctrl_error(),
 .t_awg_ctrl_loaded(),
 .t_awg_ctrl_active_valid(),
 .t_awg_ctrl_done_op(),
 .t_awg_play('0),
 .t_awg_play_accepted(),
 .t_awg_play_rejected(),
 .t_awg_busy(),
 .t_awg_done(),
 .t_awg_done_cancelled(),
 .t_active_mode(mode),
 .t_mode_accepted(),
 .t_mode_rejected(),
 .t_config_accepted(),
 .t_config_rejected(),
 .t_pipeline_ready(pipe_ready),
 .t_start_ready(),
 .t_sources_drained(),.t_lifecycle_ready(1'b1),.t_tail_empty(),
 .t_active_config_id(),
 .t_calibrated_i(),
 .t_calibrated_q(),
 .t_calibrated_valid(),
 .t_calibration_saturated(),
 .t_tx_saturated(),
 .t_native_dac_valid(),
 .t_native_dac_data(dac_data),
 .clk_ctrl(mem),
 .gsc(gsc),
 .live_range('0),
 .live_range_valid('0),
 .rejected_tokens(rejected_tokens)
 );
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
  bank_generations={generation[512+:64],generation[256+:64],generation[0+:64]};
  begin_key={64'd100,owner_epoch,generation[0+:64],64'd7};measurement_key=begin_key;noise_key=begin_key;
  headers={h[2],h[1],h[0]};
  replay_quiescent=0;
  config_data=0;noise_data=0;
  wait(occupancy==4);repeat(20)tick();
  if(completed!=0||frozen!=16'h0010||accepted!=1)$fatal(1,"FIFO stall must retain RAW");
  mr=1;wait(out_bytes==200&&completed==1);repeat(5)tick();
  if(frozen!=16'h0010||accepted!=1||lasts!=1||!bridge_idle)$fatal(1,"single frame plus replay lease");
  if(leased!=16'h0010)$fatal(1,"actual replay lease not exported");
  if(CANCEL_ONLY||$test$plusargs("CANCEL_ONLY"))begin
   reset_request=1;repeat(100)tick();
   if(owner_epoch!=1||leased!=0||frozen!=0)$fatal(1,"soft reset stranded unsubmitted replay lease");
   $display("PASS integrated dataplane soft reset cancels unsubmitted replay lease");$finish;
  end
  binding_valid=1;repeat(5)tick();tx_request=1;
  wait(permit&&pipe_ready);repeat(3)tick();
  tx_cfg=1;tick();tx_cfg=0;repeat(3)tick();tx_mode=1;tick();tx_mode=0;repeat(3)tick();
  if(mode!=2)$fatal(1,"DRFM mode preparation");
  matrix[0+:18]=65536;matrix[108+:18]=65536;profile_commit=1;tick();profile_commit=0;tick();
  task_data=0;task_data[OWNER_EPOCH_BIT+:64]=owner_epoch;task_data[GENERATION_BIT+:64]=1;
  task_data[PULSE_ID_BIT+:64]=100;task_data[START_SEQ_BIT+:64]=16381;task_data[START_PTR_BIT+:32]=16381;
  task_data[STREAM_GROUP_ID_BIT+:32]=2;task_data[SAMPLE_COUNT_BIT+:32]=7;task_data[CONFIG_ID_BIT+:32]=7;
  task_data[FIR_ID_BIT+:32]=12;task_data[SOURCE_EPOCH_BIT+:32]=13;task_data[SOURCE_ROLE_BIT+:32]=1;
  task_data[TARGET_GSC_BIT+:64]=gsc+280;task_data[TASK_ID_BIT+:64]=1;task_data[OUTPUT_DAC_MASK_BIT+:32]=255;
  task_data[RX_CAL_ID_BIT+:32]=101;task_data[TARGET_MATRIX_ID_BIT+:32]=102;task_data[DOPPLER_PHASE_ID_BIT+:32]=103;
  task_data[OUTPUT_DAC_MASK_BIT+:32]=1;submit_valid=1;tick();submit_valid=0;
  wait(rejected);if(dut.r_reject_reason!=4||raw_count!=0||!leased[4])$fatal(1,"wrong DAC mask started or released bank");repeat(3)tick();
  task_data[OUTPUT_DAC_MASK_BIT+:32]=255;task_data[PULSE_ID_BIT+:64]=99;submit_valid=1;tick();submit_valid=0;
  wait(rejected);if(dut.r_reject_reason!=3||raw_count!=0||!leased[4])$fatal(1,"wrong pulse identity started or released bank");repeat(3)tick();
  task_data[PULSE_ID_BIT+:64]=100;task_data[TARGET_GSC_BIT+:64]=gsc+280;
  submit_valid=1;tick();submit_valid=0;if(!submit_ok)$fatal(1,"replay enqueue");check_replay=1;
  wait(dsp_done||rejected);if(rejected)$fatal(1,"real owner replay rejected %0d",dut.r_reject_reason);
  repeat(4)tick();check_replay=0;
  if(raw_count!=7||dsp_count!=69||frozen!=0||leased!=0||rejected_tokens!=0)$fatal(1,"shared RAM replay drain raw=%0d dsp=%0d frozen=%h",raw_count,dsp_count,frozen);
  repeat(65)tick();if(!saw_tx_sample||!saw_dac_output)$fatal(1,"replay did not traverse TXCAL and interpolation");
  binding_valid=0;#1;if(dac_data!=0)$fatal(1,"binding loss must zero DAC");
  reset_request=1;
  replay_quiescent=1;wait(reset_done);repeat(3)tick();
  if(owner_epoch!=1||!block_new_work)$fatal(1,"reset drained real scan and upload");
  submit_valid=1;tick();submit_valid=0;if(!dut.r_submit_rejected||dut.r_submit_reason!=2)$fatal(1,"soft reset submit silently lost");
  reset_request=0;repeat(3)tick();if(reset_busy)$fatal(1,"reset resume");
  $display("PASS integrated dataplane actual capture DMA shared RAM replay DSP TX binding reset");$finish;
 end
 initial begin #30000;$fatal(1,"timeout bytes=%0d completed=%0d RF=%0d permit=%b pipe=%b mode=%d raw=%d dsp=%d reset=%b idle=%b frozen=%h",out_bytes,completed,dut.t_rf_state,permit,pipe_ready,mode,raw_count,dsp_count,reset_request,dut.r_idle,frozen);end
endmodule

module tb_calibrator_dataplane_cancel;
 tb_calibrator_dataplane_system #(.CANCEL_ONLY(1)) run_case();
endmodule
