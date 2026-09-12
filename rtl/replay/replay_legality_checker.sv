// Combinational admission evaluated against the current head's live bank context.
module replay_legality_checker(
 input wire [1535:0] task_data,
 input wire [63:0] gsc,current_owner_epoch,current_generation,
 input wire [31:0] current_config_id,current_fir_id,current_source_epoch,
 input wire data_ready,qualified,lease_pinned,source_stable,allow_aux_replay,
 input wire task_profiles_valid,guard_clear,planned_slot_clear,rf_safe,binding_valid,resources_ready,
 input wire time_valid,latency_validated,fractional_supported,
 input wire [63:0] downstream_latency_ticks,
 output reg legal,output reg [7:0] reason,output wire [63:0] first_output_gsc
);
 import replay_control_layout_pkg::*;
 wire [31:0] group_id=task_data[STREAM_GROUP_ID_BIT+:32];
 wire [31:0] bank=task_data[BANK_ID_BIT+:32];
 wire [31:0] count=task_data[SAMPLE_COUNT_BIT+:32];
 wire [31:0] reference_index=task_data[REFERENCE_SAMPLE_INDEX_BIT+:32];
 wire [31:0] role=task_data[SOURCE_ROLE_BIT+:32];
 wire [63:0] target=task_data[TARGET_GSC_BIT+:64];
 wire [65:0] offset_ticks={32'b0,reference_index,2'b00}+{2'b0,downstream_latency_ticks};
 wire [65:0] first_wide={2'b0,target}-offset_ticks;
 wire [65:0] end_wide=first_wide+(({34'b0,count}-1'b1)<<2);
 wire [65:0] earliest={2'b0,gsc}+8;
 wire external_source=(role==1 && group_id>=1 && group_id<=3) || (role==2 && group_id==4 && allow_aux_replay);
 assign first_output_gsc=first_wide[63:0];
 always @* begin
  reason=0;
  if(!time_valid || !rf_safe || !binding_valid) reason=2;
  else if(!data_ready || !qualified || !lease_pinned || !source_stable || !external_source) reason=3;
  else if(task_data[OWNER_EPOCH_BIT+:64]!=current_owner_epoch || task_data[GENERATION_BIT+:64]!=current_generation ||
          task_data[CONFIG_ID_BIT+:32]!=current_config_id || task_data[FIR_ID_BIT+:32]!=current_fir_id ||
          task_data[SOURCE_EPOCH_BIT+:32]!=current_source_epoch || !task_profiles_valid) reason=4;
  else if(group_id<1 || group_id>4 || bank>3 || task_data[START_PTR_BIT+:32]>16383 || count<1 || count>16384 || reference_index>=count ||
          task_data[OUTPUT_DAC_MASK_BIT+:32]==0 || task_data[OUTPUT_DAC_MASK_BIT+:32]>255) reason=5;
  else if(!latency_validated || (task_data[FRACTION_Q32_BIT+:32]!=0 && !fractional_supported)) reason=6;
  else if(offset_ticks>{2'b0,target} || end_wide[65:64]!=0 || earliest[65:64]!=0) reason=7;
  else if(first_wide[1:0]!=gsc[1:0]) reason=8;
  else if(first_wide<earliest) reason=9;
  else if(!guard_clear || !planned_slot_clear) reason=13;
  else if(!resources_ready) reason=14;
  legal=(reason==0);
 end
endmodule
