// Actual RAW dispatcher and FULL_A RXCAL/FD63/target processing.
module calibrator_replay_system #(parameter integer QUEUE_DEPTH=4)(
 input wire clk,rst,submit_valid,input wire [1535:0] submit_task,
 output wire submit_accepted,submit_rejected,output wire [7:0] submit_reason,
 output wire lookup_valid,output wire [1535:0] lookup_task,input wire lookup_ready,
 input wire [63:0] gsc,current_owner_epoch,current_generation,
 input wire [31:0] current_config_id,current_fir_id,current_source_epoch,
 input wire bank_frozen,data_ready,qualified,lease_pinned,source_stable,allow_aux_replay,task_profiles_valid,
 input wire guard_clear,planned_slot_clear,rf_safe,binding_valid,resources_ready,time_valid,clock_ok,latency_validated,fractional_supported,
 input wire [63:0] downstream_latency_ticks,input wire hard_fault,abort_request,
 output wire rejected_valid,output wire [1535:0] rejected_task,output wire [7:0] reject_reason,input wire reject_ready,
 output wire task_started,output wire [1535:0] active_task,
 output wire raw_valid,output wire [63:0] raw_data,output wire raw_last,
 output wire ram_en,output wire [13:0] ram_addr,output wire [31:0] ram_group,ram_bank,
 input wire ram_response_valid,input wire [63:0] ram_data,
 output wire actual_start,actual_finish,output wire [63:0] actual_start_gsc,actual_finish_gsc,
 output wire token_valid,input wire token_ready,
 output wire [63:0] token_owner_epoch,token_generation,output wire [31:0] token_group,token_bank,token_consumer,
 output wire [7:0] token_status,output wire [31:0] queued_count,output wire idle,
 input wire profile_commit,input wire [1:0] shadow_cal_valid,input wire [63:0] shadow_dc,
 input wire [71:0] shadow_gain,input wire [143:0] shadow_matrix,input wire [7:0] shadow_fd_phase,
 input wire [31:0] shadow_fd_version,shadow_rx_cal_id,shadow_target_matrix_id,shadow_doppler_phase_id,
 input wire phase_valid,input wire signed [17:0] phase_i,phase_q,
 output wire profile_ready,profile_accepted,profile_rejected,source_ready,dsp_busy,dsp_done,dsp_cancelled,
 output wire [63:0] out_hv,output wire out_valid,out_qualified,arithmetic_saturated,output wire [31:0] table_version,
 output reg [31:0] active_rx_cal_id,active_target_matrix_id,active_doppler_phase_id,active_fd_version,
 output reg [7:0] active_fd_phase
);

 import replay_control_layout_pkg::*;
 wire reader_active,dispatcher_idle,dsp_profile_ready,dsp_profile_rejected;
 reg local_profile_rejected,profile_loaded;
 wire processing_ready=source_ready&&!dsp_busy&&!profile_commit;
 wire epoch_cancel=(reader_active||dsp_busy)&&active_task[OWNER_EPOCH_BIT+:64]!=current_owner_epoch;
 wire processing_fault=hard_fault||abort_request||!rf_safe||!binding_valid||!time_valid||!clock_ok||epoch_cancel||(token_valid&&token_status!=0);
 assign profile_ready=dsp_profile_ready&&!reader_active&&!task_started;
 wire dsp_profile_commit=profile_commit&&profile_ready;
 wire load_profile=dsp_profile_commit&&(&shadow_cal_valid)&&shadow_fd_version==table_version;
 wire profile_match=profile_loaded&&lookup_task[RX_CAL_ID_BIT+:32]==active_rx_cal_id&&
  lookup_task[TARGET_MATRIX_ID_BIT+:32]==active_target_matrix_id&&lookup_task[DOPPLER_PHASE_ID_BIT+:32]==active_doppler_phase_id&&
  lookup_task[FRACTION_Q32_BIT+:32]=={active_fd_phase,24'd0};
 assign profile_rejected=dsp_profile_rejected||local_profile_rejected;
 assign idle=dispatcher_idle&&!dsp_busy;
 always @(posedge clk)begin
  if(rst)begin
   local_profile_rejected<=0;profile_loaded<=0;active_rx_cal_id<=0;active_target_matrix_id<=0;active_doppler_phase_id<=0;active_fd_version<=0;active_fd_phase<=0;
  end else begin
   local_profile_rejected<=profile_commit&&!profile_ready;
   if(load_profile)begin
    profile_loaded<=1;active_rx_cal_id<=shadow_rx_cal_id;active_target_matrix_id<=shadow_target_matrix_id;
    active_doppler_phase_id<=shadow_doppler_phase_id;active_fd_version<=shadow_fd_version;active_fd_phase<=shadow_fd_phase;
   end
  end
 end
 replay_task_dispatcher #(.QUEUE_DEPTH(QUEUE_DEPTH)) dispatch(
  .task_profiles_valid(task_profiles_valid&&profile_match),.processing_ready(processing_ready),.idle(dispatcher_idle),.reader_active(reader_active),.*);
 replay_processing_chain processing(.clk(clk),.rst(rst),.profile_commit(dsp_profile_commit),.hard_fault(processing_fault),
  .shadow_cal_valid(shadow_cal_valid),.shadow_dc(shadow_dc),.shadow_gain(shadow_gain),.shadow_matrix(shadow_matrix),
  .shadow_fd_phase(shadow_fd_phase),.shadow_fd_version(shadow_fd_version),.phase_valid(phase_valid),.phase_i(phase_i),.phase_q(phase_q),
  .in_valid(raw_valid),.in_last(raw_last),.in_hv(raw_data),.profile_ready(dsp_profile_ready),.profile_accepted(profile_accepted),.profile_rejected(dsp_profile_rejected),
  .source_ready(source_ready),.busy(dsp_busy),.done(dsp_done),.cancelled(dsp_cancelled),.out_hv(out_hv),.out_valid(out_valid),.out_qualified(out_qualified),
  .arithmetic_saturated(arithmetic_saturated),.table_version(table_version));
endmodule
