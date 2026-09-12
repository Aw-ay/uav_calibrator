// Instrument digital core with an AXI command gateway and actual native ADC
// production. PS/RFDC IP instances, pin binding and physical clock constraints
// remain outside this reusable core. All board evidence inputs are RF-domain.
module calibrator_instrument_core #(parameter integer PRE_SAMPLES=250,FIFO_ADDR_W=12,AWG_DEPTH=16384)(
 input wire ctrl_clk,rf_clk,mem_clk,rst_n,
 input wire [31:0] s_axi_awaddr,input wire s_axi_awvalid,output wire s_axi_awready,
 input wire [31:0] s_axi_wdata,input wire [3:0] s_axi_wstrb,input wire s_axi_wvalid,output wire s_axi_wready,
 output wire [1:0] s_axi_bresp,output wire s_axi_bvalid,input wire s_axi_bready,
 input wire [31:0] s_axi_araddr,input wire s_axi_arvalid,output wire s_axi_arready,
 output wire [31:0] s_axi_rdata,output wire [1:0] s_axi_rresp,output wire s_axi_rvalid,input wire s_axi_rready,output wire irq,
 input wire [1023:0] native_adc_data,input wire [15:0] native_adc_valid,output wire [15:0] native_adc_ready,
 output wire [1023:0] native_dac_data,output wire [7:0] native_dac_valid,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,output wire m_axis_tvalid,m_axis_tlast,input wire m_axis_tready,
 input wire common_clock_good,time_valid,mapping_valid,input wire [7:0] mts_locked,input wire [23:0] logical_to_physical,
 input wire [7:0] hard_overrange_event,hard_overrange_known,
 input wire [31:0] source_epoch,input wire source_stable,profiles_authorized,guard_clear,planned_slot_clear,latency_validated,live_range_authorized,
 input wire [63:0] downstream_latency_ticks,input wire phase_valid,input wire signed [17:0] phase_i,phase_q,
 input wire binding_valid,timing_valid,hard_fault,pll_locked,heartbeat,pa_on_fb,tr_tx_fb,rx_protected_fb,single_antenna_ota,
 input wire [31:0] protect_cycles,switch_cycles,pa_cycles,recovery_cycles,transition_timeout_cycles,watchdog_cycles,
 output wire pa_enable_req,tr_tx_req,rx_protect_req,rf_dac_mute,rf_fault,unbound,
 output wire run_enable,config_loaded,output wire [63:0] gsc
);
 import instrument_control_pkg::*;
 wire rst=!rst_n;
 wire cmd_valid,cmd_ready,result_valid,result_ready;
 wire [15:0] cmd_opcode,cmd_words,result_words;wire [31:0] cmd_sequence;
 wire [8191:0] cmd_payload,result_payload,config_image,action_payload;
 wire [7:0] result_code;wire rf_arm,rf_request,reset_request,action_valid;wire [15:0] action_opcode;
 reg outcome_valid;reg [7:0] outcome_code;reg [15:0] outcome_words;reg [8191:0] outcome_payload;
 wire source_idle,detector_active;wire [31:0] source_dropped;
 wire sample_valid;wire [63:0] sample_seq,sample_gsc;wire [255:0] group_data;wire [7:0] logical_good;
 wire onset_valid;wire [63:0] onset_seq,onset_gsc,onset_pulse_id;wire [1023:0] onset_config,onset_metadata;wire [255:0] onset_noise;
 wire [5:0] onset_bad_channels;wire onset_want_replay,eop_event_valid;wire [63:0] eop_event_pulse_id,eop_event_owner_epoch,eop_event_stop;wire [5:0] eop_event_bad_channels;
 reg [63:0] native_seq;
 always @(posedge rf_clk)if(rst)native_seq<=0;else native_seq<=native_seq+1'b1;
 gsc_timebase timebase(.rf_clk(rf_clk),.rst_n(rst_n),.gsc(gsc));
 reg pdw_available_rf;
 always @(posedge rf_clk or negedge rst_n)begin
  if(!rst_n)pdw_available_rf<=0;else pdw_available_rf<=pdw_count!=0;
 end
 command_gateway_axi gateway(.*);
 wire pdw_valid;wire [255:0] pdw_key;wire [1023:0] pdw_header;wire [511:0] pdw_stats;wire [191:0] pdw_peaks;
 wire [31:0] pdw_count,pdw_dropped;wire [63:0] pdw_token;wire [511:0] pdw_data;wire pdw_pop_ok;
 qualified_pdw_queue #(.PRE_SAMPLES(PRE_SAMPLES),.ADDR_W($clog2(PDW_QUEUE_DEPTH))) pdw_queue(
  .clk(rf_clk),.rst(rst),.in_valid(pdw_valid),.event_key(pdw_key),.event_header(pdw_header),.event_stats(pdw_stats),.event_peaks(pdw_peaks),
  .post_samples(config_image[CFG_POST_SAMPLES_BIT+:CFG_POST_SAMPLES_WIDTH]),
  .pop_valid(action_valid&&action_opcode==instrument_control_pkg::CMD_PDW_POP),.pop_token(action_payload[63:0]),
  .count(pdw_count),.dropped(pdw_dropped),.head_token(pdw_token),.head_data(pdw_data),.pop_ok(pdw_pop_ok));
 wire [15:0] d_replay_leased;
 wire  d_onset_ready;
 wire  d_onset_accepted;
 wire  d_onset_rejected;
 wire  d_eop_accepted;
 wire  d_eop_rejected;
 wire  d_producer_error_valid;
 wire  d_producer_error_bound;
 wire [255:0] d_producer_error_key;
 wire [5:0] d_producer_error_bank_ids;
 wire [191:0] d_producer_error_generations;
 wire [7:0] d_producer_error_reason;
 wire [31:0] d_onset_reject_count;
 wire [31:0] d_eop_reject_count;
 wire [31:0] d_context_error_count;
 wire  d_header_error;
 wire [7:0] d_statistics_error;
 wire  d_disposition_valid;
 wire  d_descriptor_accepted;
 wire  d_disposition_rejected;
 wire  d_completion_valid;
 wire  d_completion_error;
 wire [63:0] d_completion_epoch;
 wire [63:0] d_completion_generation;
 wire [1:0] d_completion_group;
 wire [1:0] d_completion_bank;
 wire [31:0] d_record_errors;
 wire [31:0] d_rejected_returns;
 wire [31:0] d_dropped_triggers;
 wire [15:0] d_write_enable;
 wire [15:0] d_armed;
 wire [15:0] d_pending;
 wire [15:0] d_frozen;
 wire [15:0] d_truncated;
 wire [15:0] d_qualified;
 wire [1023:0] d_start_seq;
 wire [1023:0] d_generation;
 wire [1023:0] d_pulse_id;
 wire [239:0] d_sample_count;
 wire [63:0] d_owner_epoch;
 wire  d_quiesce;
 wire  d_idle_rf;
 wire  d_primary_admitted;
 wire  d_block_new_work;
 wire  d_reset_busy;
 wire  d_reset_done;
 wire [127:0] d_m_axis_tdata;
 wire [15:0] d_m_axis_tkeep;
 wire  d_m_axis_tlast;
 wire  d_m_axis_tvalid;
 wire [FIFO_ADDR_W:0] d_fifo_occupancy;
 wire  d_r_submit_accepted;
 wire  d_r_submit_rejected;
 wire [7:0] d_r_submit_reason;
 wire  d_r_lookup_valid;
 wire [1535:0] d_r_lookup_task;
 wire  d_r_rejected_valid;
 wire [1535:0] d_r_rejected_task;
 wire [7:0] d_r_reject_reason;
 wire  d_r_task_started;
 wire [1535:0] d_r_active_task;
 wire  d_r_raw_valid;
 wire [63:0] d_r_raw_data;
 wire  d_r_raw_last;
 wire  d_r_ram_en;
 wire [13:0] d_r_ram_addr;
 wire [31:0] d_r_ram_group;
 wire [31:0] d_r_ram_bank;
 wire  d_r_actual_start;
 wire  d_r_actual_finish;
 wire [63:0] d_r_actual_start_gsc;
 wire [63:0] d_r_actual_finish_gsc;
 wire  d_r_token_valid;
 wire [63:0] d_r_token_owner_epoch;
 wire [63:0] d_r_token_generation;
 wire [31:0] d_r_token_group;
 wire [31:0] d_r_token_bank;
 wire [31:0] d_r_token_consumer;
 wire [7:0] d_r_token_status;
 wire [31:0] d_r_queued_count;
 wire  d_r_idle;
 wire  d_r_profile_ready;
 wire  d_r_profile_accepted;
 wire  d_r_profile_rejected;
 wire  d_r_source_ready;
 wire  d_r_dsp_busy;
 wire  d_r_dsp_done;
 wire  d_r_dsp_cancelled;
 wire [63:0] d_r_out_hv;
 wire  d_r_out_valid;
 wire  d_r_out_qualified;
 wire  d_r_arithmetic_saturated;
 wire [31:0] d_r_table_version;
 wire [31:0] d_r_active_rx_cal_id;
 wire [31:0] d_r_active_target_matrix_id;
 wire [31:0] d_r_active_doppler_phase_id;
 wire [31:0] d_r_active_fd_version;
 wire [7:0] d_r_active_fd_phase;
 wire  d_t_pa_enable_req;
 wire  d_t_tr_tx_req;
 wire  d_t_rx_protect_req;
 wire  d_t_rf_dac_mute;
 wire  d_t_rf_fault;
 wire  d_t_unbound;
 wire  d_t_rf_permit;
 wire [2:0] d_t_rf_state;
 wire  d_t_dds_accepted;
 wire  d_t_dds_rejected;
 wire  d_t_dds_busy;
 wire  d_t_dds_done;
 wire  d_t_awg_ctrl_ready;
 wire  d_t_awg_ctrl_done;
 wire  d_t_awg_ctrl_error;
 wire  d_t_awg_ctrl_loaded;
 wire  d_t_awg_ctrl_active_valid;
 wire [1:0] d_t_awg_ctrl_done_op;
 wire  d_t_awg_play_accepted;
 wire  d_t_awg_play_rejected;
 wire  d_t_awg_busy;
 wire  d_t_awg_done;
 wire  d_t_awg_done_cancelled;
 wire [2:0] d_t_active_mode;
 wire  d_t_mode_accepted;
 wire  d_t_mode_rejected;
 wire  d_t_config_accepted;
 wire  d_t_config_rejected;
 wire  d_t_pipeline_ready;
 wire  d_t_start_ready;
 wire  d_t_sources_drained;
 wire [31:0] d_t_active_config_id;
 wire [127:0] d_t_calibrated_i;
 wire [127:0] d_t_calibrated_q;
 wire [7:0] d_t_calibrated_valid;
 wire [7:0] d_t_calibration_saturated;
 wire [7:0] d_t_tx_saturated;
 wire [7:0] d_t_native_dac_valid;
 wire [1023:0] d_t_native_dac_data;
 wire [31:0] d_rejected_tokens;
 wire candidate_valid=(cmd_payload[CONFIG_WORDS*32-1:0]&~CONFIG_MASK[CONFIG_WORDS*32-1:0])==0&&
  cmd_payload[CFG_CONFIG_VERSION_BIT+:32]!=0&&cmd_payload[CFG_DETECTOR_RANGE_BIT+:2]<3&&
  cmd_payload[CFG_ON_POWER_BIT+:33]>cmd_payload[CFG_OFF_POWER_BIT+:33]&&
  cmd_payload[CFG_MAX_BODY_BIT+:14]!=0&&cmd_payload[CFG_MAX_BODY_BIT+:14]<=15000&&
  (PRE_SAMPLES+{16'd0,cmd_payload[CFG_POST_SAMPLES_BIT+:16]}+{18'd0,cmd_payload[CFG_MAX_BODY_BIT+:14]})<=16384;
 wire safe_config=source_idle&&d_idle_rf&&d_r_idle&&d_t_sources_drained&&d_frozen==0&&d_pending==0&&!d_reset_busy;
 wire acquisition_ready=common_clock_good&&time_valid&&((logical_good&8'h77)==8'h77);
 reg [1023:0] capture_metadata;
 always @*begin
  capture_metadata=config_image[CFG_METADATA_BIT+:CFG_METADATA_WIDTH];
  for(integer group_index=0;group_index<3;group_index=group_index+1)
   capture_metadata[calibrator_contract_pkg::FRAME_RESERVED_OFFSET*8+group_index*8+:8]=
      (8'b1<<logical_to_physical[group_index*3+:3])|
      (8'b1<<logical_to_physical[(group_index+4)*3+:3]);
 end
 instrument_command_executor executor(.clk(rf_clk),.rst(rst),.binding_valid(binding_valid&&timing_valid),.*);
 calibrator_receive_frontend frontend(.clk_rf(rf_clk),.rst(rst),.enable(config_loaded),
  .native_adc_data(native_adc_data),.native_adc_valid(native_adc_valid),.native_adc_ready(native_adc_ready),
  .native_seq(native_seq),.native_gsc(gsc),.common_clock_good(common_clock_good),.mts_locked(mts_locked),.mapping_valid(mapping_valid),.logical_to_physical(logical_to_physical),
  .near_clip_threshold(config_image[CFG_NEAR_CLIP_THRESHOLD_BIT+:CFG_NEAR_CLIP_THRESHOLD_WIDTH]),.threshold_validated(config_image[CFG_THRESHOLD_VALIDATED_BIT+:CFG_THRESHOLD_VALIDATED_WIDTH]),.hard_overrange_event(hard_overrange_event),.hard_overrange_known(hard_overrange_known),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.sample_gsc(sample_gsc),.group_data(group_data),.logical_good(logical_good),.logical_saturated(),.physical_good(),.physical_saturated());
 receive_event_producer #(.PRE_SAMPLES(PRE_SAMPLES)) producer(.clk(rf_clk),.rst(rst),.enable(run_enable),.block_new_work(d_block_new_work),.time_valid(time_valid),
  .sample_valid(sample_valid),.sample_seq(sample_seq),.sample_gsc(sample_gsc),.group_data(group_data),.logical_good(logical_good),
  .detector_range(config_image[CFG_DETECTOR_RANGE_BIT+:CFG_DETECTOR_RANGE_WIDTH]),
  .on_power(config_image[CFG_ON_POWER_BIT+:CFG_ON_POWER_WIDTH]),
  .off_power(config_image[CFG_OFF_POWER_BIT+:CFG_OFF_POWER_WIDTH]),
  .eop_hold(config_image[CFG_EOP_HOLD_BIT+:CFG_EOP_HOLD_WIDTH]),
  .max_body(config_image[CFG_MAX_BODY_BIT+:CFG_MAX_BODY_WIDTH]),
  .post_samples(config_image[CFG_POST_SAMPLES_BIT+:CFG_POST_SAMPLES_WIDTH]),
  .noise_enable(config_image[CFG_NOISE_ENABLE_BIT+:CFG_NOISE_ENABLE_WIDTH]),
  .noise_shift(config_image[CFG_NOISE_SHIFT_BIT+:CFG_NOISE_SHIFT_WIDTH]),
  .noise_max_age(config_image[CFG_NOISE_MAX_AGE_BIT+:CFG_NOISE_MAX_AGE_WIDTH]),
  .detector_validated(config_loaded),.owner_epoch(d_owner_epoch),.config_version({32'd0,config_image[CFG_CONFIG_VERSION_BIT+:CFG_CONFIG_VERSION_WIDTH]}),
  .config_data(config_image[CFG_QUALIFICATION_BIT+:CFG_QUALIFICATION_WIDTH]),.metadata(capture_metadata),.want_replay(config_image[CFG_WANT_REPLAY_BIT+:CFG_WANT_REPLAY_WIDTH]),
  .onset_ready(d_onset_ready),.idle(source_idle),.dropped_onsets(source_dropped),.*);
 wire mode_payload_ok=action_payload[31:3]==0&&action_payload[2:0]<=4;
 wire dds_payload_ok=action_payload[287:257]==0;
 wire awg_payload_ok=action_payload[31:2]==0;
 // A loaded COMMIT cannot wait for a later STOP/MODE command on this
 // single-inflight gateway. Keep the inactive table and let PS retry in MUTE.
 wire awg_commit_blocked=(action_payload[1:0]==2)&&d_t_awg_ctrl_loaded&&
  (run_enable||(d_t_active_mode!=0)||!d_r_idle||!d_t_sources_drained||detector_active);
 calibrator_dataplane_system #(.PRE_SAMPLES(PRE_SAMPLES),.DETECTOR_LATENCY(2),.FIFO_ADDR_W(FIFO_ADDR_W),.AWG_DEPTH(AWG_DEPTH),.PHYSICAL_MASKS_IN_TEMPLATE(1)) dataplane(
  .replay_leased(d_replay_leased),
  .clk_rf(rf_clk),
  .clk_mem(mem_clk),
  .rst_n(rst_n),
  .arm_enable(run_enable),
  .reset_request(reset_request),
  .sample_valid(sample_valid),
  .sample_seq(sample_seq),
  .group_data(group_data),
  .onset_valid(onset_valid),
  .onset_ready(d_onset_ready),
  .onset_accepted(d_onset_accepted),
  .onset_rejected(d_onset_rejected),
  .onset_seq(onset_seq),
  .onset_gsc(onset_gsc),
  .onset_pulse_id(onset_pulse_id),
  .config_version({32'd0,config_image[CFG_CONFIG_VERSION_BIT+:CFG_CONFIG_VERSION_WIDTH]}),
  .onset_config(onset_config),
  .onset_metadata(onset_metadata),
  .onset_noise(onset_noise),
  .onset_bad_channels(onset_bad_channels),
  .onset_want_replay(onset_want_replay),
  .eop_event_valid(eop_event_valid),
  .eop_event_pulse_id(eop_event_pulse_id),
  .eop_event_owner_epoch(eop_event_owner_epoch),
  .eop_event_stop(eop_event_stop),
  .eop_event_bad_channels(eop_event_bad_channels),
  .eop_accepted(d_eop_accepted),
  .eop_rejected(d_eop_rejected),
  .producer_error_valid(d_producer_error_valid),
  .producer_error_bound(d_producer_error_bound),
  .producer_error_ready(action_valid&&action_opcode==instrument_control_pkg::CMD_PRODUCER_ERROR_POP&&d_producer_error_valid),
  .producer_error_key(d_producer_error_key),
  .producer_error_bank_ids(d_producer_error_bank_ids),
  .producer_error_generations(d_producer_error_generations),
  .producer_error_reason(d_producer_error_reason),
  .onset_reject_count(d_onset_reject_count),
  .eop_reject_count(d_eop_reject_count),
  .context_error_count(d_context_error_count),
  .header_error(d_header_error),
  .statistics_error(d_statistics_error),
  .pdw_valid(pdw_valid),.pdw_key(pdw_key),.pdw_header(pdw_header),.pdw_stats(pdw_stats),.pdw_peaks(pdw_peaks),
  .disposition_valid(d_disposition_valid),
  .descriptor_accepted(d_descriptor_accepted),
  .disposition_rejected(d_disposition_rejected),
  .completion_valid(d_completion_valid),
  .completion_error(d_completion_error),
  .completion_epoch(d_completion_epoch),
  .completion_generation(d_completion_generation),
  .completion_group(d_completion_group),
  .completion_bank(d_completion_bank),
  .record_errors(d_record_errors),
  .rejected_returns(d_rejected_returns),
  .dropped_triggers(d_dropped_triggers),
  .write_enable(d_write_enable),
  .armed(d_armed),
  .pending(d_pending),
  .frozen(d_frozen),
  .truncated(d_truncated),
  .qualified(d_qualified),
  .start_seq(d_start_seq),
  .generation(d_generation),
  .pulse_id(d_pulse_id),
  .sample_count(d_sample_count),
  .owner_epoch(d_owner_epoch),
  .quiesce(d_quiesce),
  .idle_rf(d_idle_rf),
  .primary_admitted(d_primary_admitted),
  .block_new_work(d_block_new_work),
  .reset_busy(d_reset_busy),
  .reset_done(d_reset_done),
  .m_axis_tdata(d_m_axis_tdata),
  .m_axis_tkeep(d_m_axis_tkeep),
  .m_axis_tlast(d_m_axis_tlast),
  .m_axis_tvalid(d_m_axis_tvalid),
  .m_axis_tready(m_axis_tready),
  .fifo_occupancy(d_fifo_occupancy),
  .r_submit_valid(action_valid&&action_opcode==instrument_control_pkg::CMD_REPLAY),
  .r_submit_task(action_payload[1535:0]),
  .r_submit_accepted(d_r_submit_accepted),
  .r_submit_rejected(d_r_submit_rejected),
  .r_submit_reason(d_r_submit_reason),
  .r_lookup_valid(d_r_lookup_valid),
  .r_lookup_task(d_r_lookup_task),
  .r_current_config_id(config_image[CFG_CONFIG_VERSION_BIT+:CFG_CONFIG_VERSION_WIDTH]),
  .r_current_fir_id(config_image[CFG_R_CURRENT_FIR_ID_BIT+:CFG_R_CURRENT_FIR_ID_WIDTH]),
  .r_current_source_epoch(source_epoch),
  .r_source_stable(source_stable),
  .r_allow_aux_replay(1'b0),
  .r_task_profiles_valid(profiles_authorized),
  .r_guard_clear(guard_clear),
  .r_planned_slot_clear(planned_slot_clear),
  .r_resources_ready(1'b1),
  .r_time_valid(time_valid),
  .r_clock_ok(common_clock_good),
  .r_latency_validated(latency_validated),
  .r_fractional_supported(1'b1),
  .r_downstream_latency_ticks(downstream_latency_ticks),
  .r_rejected_valid(d_r_rejected_valid),
  .r_rejected_task(d_r_rejected_task),
  .r_reject_reason(d_r_reject_reason),
  .r_reject_ready(action_valid&&action_opcode==instrument_control_pkg::CMD_REJECT_POP&&d_r_rejected_valid),
  .r_task_started(d_r_task_started),
  .r_active_task(d_r_active_task),
  .r_raw_valid(d_r_raw_valid),
  .r_raw_data(d_r_raw_data),
  .r_raw_last(d_r_raw_last),
  .r_ram_en(d_r_ram_en),
  .r_ram_addr(d_r_ram_addr),
  .r_ram_group(d_r_ram_group),
  .r_ram_bank(d_r_ram_bank),
  .r_actual_start(d_r_actual_start),
  .r_actual_finish(d_r_actual_finish),
  .r_actual_start_gsc(d_r_actual_start_gsc),
  .r_actual_finish_gsc(d_r_actual_finish_gsc),
  .r_token_valid(d_r_token_valid),
  .r_token_owner_epoch(d_r_token_owner_epoch),
  .r_token_generation(d_r_token_generation),
  .r_token_group(d_r_token_group),
  .r_token_bank(d_r_token_bank),
  .r_token_consumer(d_r_token_consumer),
  .r_token_status(d_r_token_status),
  .r_queued_count(d_r_queued_count),
  .r_idle(d_r_idle),
  .r_profile_commit(action_valid&&action_opcode==instrument_control_pkg::CMD_RX_PROFILE),
  .r_shadow_cal_valid(config_image[CFG_R_SHADOW_CAL_VALID_BIT+:CFG_R_SHADOW_CAL_VALID_WIDTH]),
  .r_shadow_dc(config_image[CFG_R_SHADOW_DC_BIT+:CFG_R_SHADOW_DC_WIDTH]),
  .r_shadow_gain(config_image[CFG_R_SHADOW_GAIN_BIT+:CFG_R_SHADOW_GAIN_WIDTH]),
  .r_shadow_matrix(config_image[CFG_R_SHADOW_MATRIX_BIT+:CFG_R_SHADOW_MATRIX_WIDTH]),
  .r_shadow_fd_phase(config_image[CFG_R_SHADOW_FD_PHASE_BIT+:CFG_R_SHADOW_FD_PHASE_WIDTH]),
  .r_shadow_fd_version(config_image[CFG_R_SHADOW_FD_VERSION_BIT+:CFG_R_SHADOW_FD_VERSION_WIDTH]),
  .r_shadow_rx_cal_id(config_image[CFG_R_SHADOW_RX_CAL_ID_BIT+:CFG_R_SHADOW_RX_CAL_ID_WIDTH]),
  .r_shadow_target_matrix_id(config_image[CFG_R_SHADOW_TARGET_MATRIX_ID_BIT+:CFG_R_SHADOW_TARGET_MATRIX_ID_WIDTH]),
  .r_shadow_doppler_phase_id(config_image[CFG_R_SHADOW_DOPPLER_PHASE_ID_BIT+:CFG_R_SHADOW_DOPPLER_PHASE_ID_WIDTH]),
  .r_phase_valid(phase_valid),
  .r_phase_i(phase_i),.r_phase_q(phase_q),
  .r_profile_ready(d_r_profile_ready),
  .r_profile_accepted(d_r_profile_accepted),
  .r_profile_rejected(d_r_profile_rejected),
  .r_source_ready(d_r_source_ready),
  .r_dsp_busy(d_r_dsp_busy),
  .r_dsp_done(d_r_dsp_done),
  .r_dsp_cancelled(d_r_dsp_cancelled),
  .r_out_hv(d_r_out_hv),
  .r_out_valid(d_r_out_valid),
  .r_out_qualified(d_r_out_qualified),
  .r_arithmetic_saturated(d_r_arithmetic_saturated),
  .r_table_version(d_r_table_version),
  .r_active_rx_cal_id(d_r_active_rx_cal_id),
  .r_active_target_matrix_id(d_r_active_target_matrix_id),
  .r_active_doppler_phase_id(d_r_active_doppler_phase_id),
  .r_active_fd_version(d_r_active_fd_version),
  .r_active_fd_phase(d_r_active_fd_phase),
  .t_binding_valid(binding_valid),
  .t_timing_valid(timing_valid),
  .t_arm(rf_arm),
  .t_tx_request(rf_request),
  .t_hard_fault(hard_fault),
  .t_pll_locked(pll_locked),
  .t_heartbeat(heartbeat),
  .t_clear_fault(action_valid&&action_opcode==instrument_control_pkg::CMD_RF_REQUEST&&action_payload[2]),
  .t_pa_on_fb(pa_on_fb),
  .t_tr_tx_fb(tr_tx_fb),
  .t_rx_protected_fb(rx_protected_fb),
  .t_protect_cycles(protect_cycles),
  .t_switch_cycles(switch_cycles),
  .t_pa_cycles(pa_cycles),
  .t_recovery_cycles(recovery_cycles),
  .t_transition_timeout_cycles(transition_timeout_cycles),
  .t_watchdog_cycles(watchdog_cycles),
  .t_pa_enable_req(d_t_pa_enable_req),
  .t_tr_tx_req(d_t_tr_tx_req),
  .t_rx_protect_req(d_t_rx_protect_req),
  .t_rf_dac_mute(d_t_rf_dac_mute),
  .t_rf_fault(d_t_rf_fault),
  .t_unbound(d_t_unbound),
  .t_rf_permit(d_t_rf_permit),
  .t_rf_state(d_t_rf_state),
  .t_stop_request(!rf_arm),
  .t_safe_boundary(d_r_idle&&d_t_sources_drained&&!detector_active),
  .t_mode_request(action_valid&&action_opcode==instrument_control_pkg::CMD_MODE&&mode_payload_ok),
  .t_config_commit(action_valid&&action_opcode==instrument_control_pkg::CMD_TX_PROFILE),
  .t_single_antenna_ota(single_antenna_ota),
  .t_requested_mode(action_payload[2:0]),
  .t_route_select(config_image[CFG_T_ROUTE_SELECT_BIT+:CFG_T_ROUTE_SELECT_WIDTH]),
  .t_route_enable(config_image[CFG_T_ROUTE_ENABLE_BIT+:CFG_T_ROUTE_ENABLE_WIDTH]),
  .t_cal_valid(config_image[CFG_T_CAL_VALID_BIT+:CFG_T_CAL_VALID_WIDTH]),
  .t_dc_i(config_image[CFG_T_DC_I_BIT+:CFG_T_DC_I_WIDTH]),
  .t_dc_q(config_image[CFG_T_DC_Q_BIT+:CFG_T_DC_Q_WIDTH]),
  .t_gain_i(config_image[CFG_T_GAIN_I_BIT+:CFG_T_GAIN_I_WIDTH]),
  .t_gain_q(config_image[CFG_T_GAIN_Q_BIT+:CFG_T_GAIN_Q_WIDTH]),
  .t_config_id(config_image[CFG_T_CONFIG_ID_BIT+:CFG_T_CONFIG_ID_WIDTH]),
  .t_dds_cmd_valid(action_valid&&action_opcode==instrument_control_pkg::CMD_DDS&&dds_payload_ok),
  .t_dds_start_gsc(action_payload[63:0]),
  .t_dds_pw_samples(action_payload[95:64]),
  .t_dds_pri_samples(action_payload[127:96]),
  .t_dds_pulse_count(action_payload[159:128]),
  .t_dds_initial_pinc(action_payload[207:160]),
  .t_dds_chirp_step(action_payload[255:208]),
  .t_dds_reset_each_pulse(action_payload[256]),
  .t_dds_accepted(d_t_dds_accepted),
  .t_dds_rejected(d_t_dds_rejected),
  .t_dds_busy(d_t_dds_busy),
  .t_dds_done(d_t_dds_done),
  .t_awg_ctrl_valid(action_valid&&action_opcode==instrument_control_pkg::CMD_AWG_LOAD&&awg_payload_ok&&d_t_awg_ctrl_ready&&!awg_commit_blocked),
  .t_awg_ctrl_op(action_payload[1:0]),
  .t_awg_ctrl_length(action_payload[63:32]),
  .t_awg_ctrl_crc32c(action_payload[95:64]),
  .t_awg_ctrl_data(action_payload[159:96]),
  .t_awg_ctrl_ready(d_t_awg_ctrl_ready),
  .t_awg_ctrl_done(d_t_awg_ctrl_done),
  .t_awg_ctrl_error(d_t_awg_ctrl_error),
  .t_awg_ctrl_loaded(d_t_awg_ctrl_loaded),
  .t_awg_ctrl_active_valid(d_t_awg_ctrl_active_valid),
  .t_awg_ctrl_done_op(d_t_awg_ctrl_done_op),
  .t_awg_play(action_valid&&action_opcode==instrument_control_pkg::CMD_AWG_PLAY),
  .t_awg_play_accepted(d_t_awg_play_accepted),
  .t_awg_play_rejected(d_t_awg_play_rejected),
  .t_awg_busy(d_t_awg_busy),
  .t_awg_done(d_t_awg_done),
  .t_awg_done_cancelled(d_t_awg_done_cancelled),
  .t_active_mode(d_t_active_mode),
  .t_mode_accepted(d_t_mode_accepted),
  .t_mode_rejected(d_t_mode_rejected),
  .t_config_accepted(d_t_config_accepted),
  .t_config_rejected(d_t_config_rejected),
  .t_pipeline_ready(d_t_pipeline_ready),
  .t_start_ready(d_t_start_ready),
  .t_sources_drained(d_t_sources_drained),
  .t_active_config_id(d_t_active_config_id),
  .t_calibrated_i(d_t_calibrated_i),
  .t_calibrated_q(d_t_calibrated_q),
  .t_calibrated_valid(d_t_calibrated_valid),
  .t_calibration_saturated(d_t_calibration_saturated),
  .t_tx_saturated(d_t_tx_saturated),
  .t_native_dac_valid(d_t_native_dac_valid),
  .t_native_dac_data(d_t_native_dac_data),
  .clk_ctrl(rf_clk),
  .gsc(gsc),
  .live_range(config_image[CFG_DETECTOR_RANGE_BIT+:CFG_DETECTOR_RANGE_WIDTH]),
  .live_range_valid(live_range_authorized),
  .rejected_tokens(d_rejected_tokens)
 );
 assign native_dac_data=d_t_native_dac_data;
 assign native_dac_valid=d_t_native_dac_valid;
 assign pa_enable_req=d_t_pa_enable_req;
 assign tr_tx_req=d_t_tr_tx_req;
 assign rx_protect_req=d_t_rx_protect_req;
 assign rf_dac_mute=d_t_rf_dac_mute;
 assign rf_fault=d_t_rf_fault;
 assign unbound=d_t_unbound;
 assign m_axis_tdata=d_m_axis_tdata;
 assign m_axis_tkeep=d_m_axis_tkeep;
 assign m_axis_tvalid=d_m_axis_tvalid;
 assign m_axis_tlast=d_m_axis_tlast;
 always @*begin
  outcome_valid=0;outcome_code=0;outcome_words=0;outcome_payload=0;
  case(action_opcode)
   instrument_control_pkg::CMD_RESET:outcome_valid=d_reset_done;
   instrument_control_pkg::CMD_MODE:begin outcome_valid=(action_valid&&!mode_payload_ok)||d_t_mode_accepted||d_t_mode_rejected;outcome_code=!mode_payload_ok?8'd2:(d_t_mode_rejected?8'd4:8'd0);end
   instrument_control_pkg::CMD_RX_PROFILE:begin outcome_valid=d_r_profile_accepted||d_r_profile_rejected;outcome_code=d_r_profile_rejected?8'd4:8'd0;end
   instrument_control_pkg::CMD_TX_PROFILE:begin outcome_valid=d_t_config_accepted||d_t_config_rejected;outcome_code=d_t_config_rejected?8'd4:8'd0;end
   instrument_control_pkg::CMD_REPLAY:begin outcome_valid=d_r_submit_accepted||d_r_submit_rejected;outcome_code=d_r_submit_rejected?8'd4:8'd0;outcome_words=1;outcome_payload[7:0]=d_r_submit_reason;end
   instrument_control_pkg::CMD_DDS:begin outcome_valid=(action_valid&&!dds_payload_ok)||d_t_dds_accepted||d_t_dds_rejected;outcome_code=!dds_payload_ok?8'd2:(d_t_dds_rejected?8'd4:8'd0);end
   instrument_control_pkg::CMD_AWG_LOAD:begin
    outcome_valid=(action_valid&&(!awg_payload_ok||!d_t_awg_ctrl_ready||awg_commit_blocked))||d_t_awg_ctrl_done;
    outcome_code=!awg_payload_ok?8'd2:((action_valid&&(!d_t_awg_ctrl_ready||awg_commit_blocked))?8'd3:(d_t_awg_ctrl_error?8'd4:8'd0));
    outcome_words=1;outcome_payload[3:0]={d_t_awg_ctrl_active_valid,d_t_awg_ctrl_loaded,d_t_awg_ctrl_done_op};
   end
   instrument_control_pkg::CMD_AWG_PLAY:begin outcome_valid=d_t_awg_play_accepted||d_t_awg_play_rejected;outcome_code=d_t_awg_play_rejected?8'd4:8'd0;end
   instrument_control_pkg::CMD_PDW_PEEK:begin
    outcome_valid=action_valid;outcome_words=CMD_PDW_PEEK_RESULT_WORDS;outcome_payload[639:0]={pdw_data,pdw_token,pdw_dropped,pdw_count};
   end
   instrument_control_pkg::CMD_PDW_POP:begin outcome_valid=action_valid;outcome_code=pdw_pop_ok?8'd0:8'd4;end
   instrument_control_pkg::CMD_STATUS:begin
    outcome_valid=action_valid;outcome_words=116;
    outcome_payload[63:0]=gsc;outcome_payload[127:64]=d_owner_epoch;
    outcome_payload[159:128]=config_image[CFG_CONFIG_VERSION_BIT+:32];
    outcome_payload[191:160]={21'd0,d_t_active_mode,d_t_rf_state,d_t_rf_permit,d_t_rf_fault,d_t_unbound,rf_arm,run_enable};
    outcome_payload[207:192]=d_armed;outcome_payload[223:208]=d_pending;outcome_payload[239:224]=d_frozen;outcome_payload[255:240]=d_replay_leased;
    outcome_payload[1279:256]=d_generation;outcome_payload[2303:1280]=d_start_seq;outcome_payload[3327:2304]=d_pulse_id;outcome_payload[3567:3328]=d_sample_count;
    outcome_payload[3599:3568]=d_record_errors;outcome_payload[3631:3600]=source_dropped;outcome_payload[3663:3632]=d_rejected_tokens;
    outcome_payload[3695:3664]=d_onset_reject_count;outcome_payload[3711:3696]={14'd0,d_producer_error_valid,d_r_rejected_valid};
   end
   instrument_control_pkg::CMD_REJECT_POP:begin outcome_valid=action_valid;outcome_code=d_r_rejected_valid?8'd0:8'd2;outcome_words=49;outcome_payload[31:0]={24'd0,d_r_reject_reason};outcome_payload[1567:32]=d_r_rejected_task;end
   instrument_control_pkg::CMD_PRODUCER_ERROR_POP:begin outcome_valid=action_valid;outcome_code=d_producer_error_valid?8'd0:8'd2;outcome_words=16;outcome_payload[31:0]={17'd0,d_producer_error_bound,d_producer_error_bank_ids,d_producer_error_reason};outcome_payload[287:32]=d_producer_error_key;outcome_payload[479:288]=d_producer_error_generations;end
   default:begin end
  endcase
 end
endmodule
