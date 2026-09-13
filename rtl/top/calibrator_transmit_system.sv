// Digital transmit subsystem only. Trusted board adapter supplies binding,
// normalized feedback and every RF dwell/timeout; no physical binding is embedded.
module calibrator_transmit_system #(parameter integer AWG_DEPTH=16384)(
 input wire clk_rf,clk_ctrl,rst_n,binding_valid,timing_valid,arm,tx_request,
 input wire hard_fault,pll_locked,heartbeat,clear_fault,
 input wire pa_on_fb,tr_tx_fb,rx_protected_fb,
 input wire [31:0] protect_cycles,switch_cycles,pa_cycles,recovery_cycles,transition_timeout_cycles,watchdog_cycles,
 output wire pa_enable_req,tr_tx_req,rx_protect_req,rf_dac_mute,rf_fault,unbound,rf_permit,
 output wire [2:0] rf_state,
 input wire lifecycle_ready,
 input wire stop_request,safe_boundary,mode_request,config_commit,single_antenna_ota,
 input wire [2:0] requested_mode,input wire [7:0] route_select,route_enable,cal_valid,
 input wire [127:0] dc_i,dc_q,input wire [143:0] gain_i,gain_q,input wire [31:0] config_id,
 input wire [63:0] live_data,drfm_data,input wire live_valid,drfm_valid,
 input wire [63:0] gsc,input wire dds_cmd_valid,input wire [63:0] dds_start_gsc,
 input wire [31:0] dds_pw_samples,dds_pri_samples,dds_pulse_count,
 input wire [47:0] dds_initial_pinc,dds_chirp_step,input wire dds_reset_each_pulse,
 output wire dds_accepted,dds_rejected,dds_busy,dds_done,
 input wire awg_ctrl_valid,input wire [1:0] awg_ctrl_op,
 input wire [31:0] awg_ctrl_length,awg_ctrl_crc32c,input wire [63:0] awg_ctrl_data,
 output wire awg_ctrl_ready,awg_ctrl_done,awg_ctrl_error,awg_ctrl_loaded,awg_ctrl_active_valid,
 output wire [1:0] awg_ctrl_done_op,input wire awg_play,
 output wire awg_play_accepted,awg_play_rejected,awg_busy,awg_done,awg_done_cancelled,
 output wire [2:0] active_mode,output wire mode_accepted,mode_rejected,config_accepted,config_rejected,
 output wire tail_empty,
 output wire pipeline_ready,start_ready,sources_drained,output wire [31:0] active_config_id,
 output wire [127:0] calibrated_i,calibrated_q,
 output wire [7:0] calibrated_valid,calibration_saturated,tx_saturated,native_dac_valid,
 output wire [1023:0] native_dac_data);
 wire [63:0] dds_data,awg_data,dds_gsc_unused,awg_gsc_unused;
 wire dds_valid,awg_valid,awg_last_unused;
 wire source_dds_rejected,source_awg_rejected,chain_mode_accepted,chain_mode_rejected;
 wire [1023:0] chain_dac_data;wire [7:0] chain_dac_valid;
 reg config_seen,local_mode_rejected,user_mode_forward_q,local_dds_rejected,local_awg_rejected;
 reg [1:0] ready_guard;
 (* ASYNC_REG="TRUE" *) reg awg_active_meta,awg_active_sync;
 always @(posedge clk_rf or negedge rst_n)
  if(!rst_n)begin awg_active_meta<=0;awg_active_sync<=0;end
  else begin awg_active_meta<=awg_ctrl_active_valid;awg_active_sync<=awg_active_meta;end
 wire mute_now=mode_request&&(requested_mode==0);
 wire force_mute=(stop_request||!rf_permit||rf_fault||hard_fault)&&(active_mode!=0);
 wire path_ready=rf_permit&&pipeline_ready&&config_seen&&!stop_request&&!mute_now;
 wire nonzero_mode_allowed=lifecycle_ready&&tail_empty&&path_ready&&safe_boundary&&sources_drained&&!force_mute;
 wire user_mode_forward=mode_request&&((requested_mode==0)||nonzero_mode_allowed);
 wire chain_mode_request=force_mute||user_mode_forward;
 wire [2:0] chain_requested_mode=force_mute?3'd0:requested_mode;
 wire chain_boundary=safe_boundary&&sources_drained;
 assign rf_permit=rst_n&&binding_valid&&timing_valid&&!rf_dac_mute&&!rf_fault;
 assign start_ready=lifecycle_ready&&tail_empty&&path_ready&&(&ready_guard)&&sources_drained&&((active_mode==3)||((active_mode==4)&&awg_active_sync));
 assign dds_rejected=local_dds_rejected||source_dds_rejected;
 assign awg_play_rejected=local_awg_rejected||source_awg_rejected;
 assign mode_accepted=chain_mode_accepted&&user_mode_forward_q;
 assign mode_rejected=local_mode_rejected||(chain_mode_rejected&&user_mode_forward_q);
 // Mask at the output as well as inside the common chain: a current MUTE or
 // safety drop must not wait for registered source/FIR data to propagate.
 assign native_dac_data=path_ready?chain_dac_data:1024'd0;
 assign native_dac_valid=path_ready?chain_dac_valid:8'hff;
 rf_safety_interlock safety(
  .clk_rf(clk_rf),.rst_n(rst_n),.binding_valid(binding_valid),.timing_valid(timing_valid),
  .arm(arm),.tx_request(tx_request&&!stop_request),.hard_fault(hard_fault),.pll_locked(pll_locked),
  .heartbeat(heartbeat),.clear_fault(clear_fault),.pa_on_fb(pa_on_fb),.tr_tx_fb(tr_tx_fb),.rx_protected_fb(rx_protected_fb),
  .protect_cycles(protect_cycles),.switch_cycles(switch_cycles),.pa_cycles(pa_cycles),.recovery_cycles(recovery_cycles),
  .transition_timeout_cycles(transition_timeout_cycles),.watchdog_cycles(watchdog_cycles),
  .pa_enable_req(pa_enable_req),.tr_tx_req(tr_tx_req),.rx_protect_req(rx_protect_req),.dac_mute(rf_dac_mute),
  .state(rf_state),.fault_latched(rf_fault),.unbound(unbound));
 generated_tx_sources #(.AWG_DEPTH(AWG_DEPTH)) generated(
  .clk_ctrl(clk_ctrl),.clk_rf(clk_rf),.rst_n(rst_n),.gsc(gsc),.stop_request(!path_ready),
  .safe_boundary(chain_boundary&&(active_mode==0)),
  .dds_cmd_valid(dds_cmd_valid&&start_ready&&(active_mode==3)),.dds_start_gsc(dds_start_gsc),
  .dds_pw_samples(dds_pw_samples),.dds_pri_samples(dds_pri_samples),.dds_pulse_count(dds_pulse_count),
  .dds_initial_pinc(dds_initial_pinc),.dds_chirp_step(dds_chirp_step),.dds_reset_each_pulse(dds_reset_each_pulse),
  .dds_accepted(dds_accepted),.dds_rejected(source_dds_rejected),.dds_busy(dds_busy),.dds_done(dds_done),
  .dds_data(dds_data),.dds_valid(dds_valid),.dds_sample_gsc(dds_gsc_unused),
  .awg_ctrl_valid(awg_ctrl_valid),.awg_ctrl_op(awg_ctrl_op),.awg_ctrl_length(awg_ctrl_length),
  .awg_ctrl_crc32c(awg_ctrl_crc32c),.awg_ctrl_data(awg_ctrl_data),.awg_ctrl_ready(awg_ctrl_ready),
  .awg_ctrl_done(awg_ctrl_done),.awg_ctrl_error(awg_ctrl_error),.awg_ctrl_done_op(awg_ctrl_done_op),
  .awg_ctrl_loaded(awg_ctrl_loaded),.awg_ctrl_active_valid(awg_ctrl_active_valid),
  .awg_play(awg_play&&start_ready&&(active_mode==4)),.awg_play_accepted(awg_play_accepted),
  .awg_play_rejected(source_awg_rejected),.awg_busy(awg_busy),.awg_done(awg_done),.awg_done_cancelled(awg_done_cancelled),
  .awg_data(awg_data),.awg_valid(awg_valid),.awg_last(awg_last_unused),.awg_sample_gsc(awg_gsc_unused),.sources_drained(sources_drained));
 tx_processing_chain chain(
  .clk_rf(clk_rf),.rst(!rst_n),.mode_request(chain_mode_request),.safe_boundary(chain_boundary),
  .rf_permit(rf_permit&&!stop_request),.hard_fault(hard_fault||rf_fault),.single_antenna_ota(single_antenna_ota),
  .config_commit(config_commit),.requested_mode(chain_requested_mode),.route_select(route_select),.route_enable(route_enable),
  .cal_valid(cal_valid),.dc_i(dc_i),.dc_q(dc_q),.gain_i(gain_i),.gain_q(gain_q),.config_id(config_id),
  .live_data(live_data),.drfm_data(drfm_data),.dds_data(dds_data),.awg_data(awg_data),
  .live_valid(live_valid&&path_ready),.drfm_valid(drfm_valid&&path_ready),.dds_valid(dds_valid),.awg_valid(awg_valid),
  .active_mode(active_mode),.mode_accepted(chain_mode_accepted),.mode_rejected(chain_mode_rejected),.pipeline_ready(pipeline_ready),
  .config_accepted(config_accepted),.config_rejected(config_rejected),.active_config_id(active_config_id),
  .calibrated_i(calibrated_i),.calibrated_q(calibrated_q),.calibrated_valid(calibrated_valid),
  .calibration_saturated(calibration_saturated),.tx_saturated(tx_saturated),
  .native_dac_valid(chain_dac_valid),.native_dac_data(chain_dac_data),.tail_empty(tail_empty));
 always @(posedge clk_rf)begin
  if(!rst_n)begin config_seen<=0;ready_guard<=0;local_mode_rejected<=0;user_mode_forward_q<=0;local_dds_rejected<=0;local_awg_rejected<=0;end
  else begin
   if(config_accepted)config_seen<=1;
   // Allows the source stop/restart latch to clear after chain permit recovers.
   if(!path_ready||active_mode==0)ready_guard<=0;else ready_guard<={ready_guard[0],1'b1};
   user_mode_forward_q<=user_mode_forward;
   local_mode_rejected<=mode_request&&!user_mode_forward;
   local_dds_rejected<=dds_cmd_valid&&!(start_ready&&active_mode==3);
   local_awg_rejected<=awg_play&&!(start_ready&&active_mode==4);
  end
 end
endmodule
