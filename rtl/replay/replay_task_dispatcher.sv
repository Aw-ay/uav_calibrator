// Queue, head-context revalidation and real fixed-latency RAW reader integration.
// No rejection path fabricates a bank-return token. All inputs are clk-domain.
module replay_task_dispatcher #(parameter integer QUEUE_DEPTH=4)(
 input wire clk,rst,submit_valid,input wire [1535:0] submit_task,
 output wire submit_accepted,submit_rejected,output wire [7:0] submit_reason,
 output wire lookup_valid,output wire [1535:0] lookup_task,input wire lookup_ready,
 input wire [63:0] gsc,current_owner_epoch,current_generation,
 input wire [31:0] current_config_id,current_fir_id,current_source_epoch,
 input wire bank_frozen,data_ready,qualified,lease_pinned,source_stable,allow_aux_replay,task_profiles_valid,
 input wire guard_clear,planned_slot_clear,rf_safe,binding_valid,resources_ready,time_valid,clock_ok,latency_validated,fractional_supported,
 input wire [63:0] downstream_latency_ticks,input wire hard_fault,abort_request,processing_ready,
 output wire rejected_valid,output wire [1535:0] rejected_task,output wire [7:0] reject_reason,input wire reject_ready,
 output wire task_started,output reg [1535:0] active_task,
 output wire raw_valid,output wire [63:0] raw_data,output wire raw_last,
 output wire ram_en,output wire [13:0] ram_addr,output wire [31:0] ram_group,ram_bank,
 input wire ram_response_valid,input wire [63:0] ram_data,
 output wire actual_start,actual_finish,output wire [63:0] actual_start_gsc,actual_finish_gsc,
 output wire token_valid,input wire token_ready,
 output wire [63:0] token_owner_epoch,token_generation,output wire [31:0] token_group,token_bank,token_consumer,
 output wire [7:0] token_status,output wire [31:0] queued_count,output wire idle,reader_active
);
 import replay_control_layout_pkg::*;
 wire legal;wire [7:0] legality_reason;wire [63:0] unused_first;
 wire dispatch_valid;wire [1535:0] dispatch_task,queue_rejected_task;
 wire queue_rejected_valid,queue_inflight,reader_ready,reader_busy,reader_rejected;
 wire [7:0] queue_reject_reason,reader_reason;
 reg failed_admission;reg [7:0] failed_reason;
 wire runtime_abort=abort_request||!rf_safe||!binding_valid;
 wire retire=(token_valid&&token_ready)||(failed_admission&&reject_ready);
 assign rejected_valid=failed_admission||queue_rejected_valid;
 assign rejected_task=failed_admission?active_task:queue_rejected_task;
 assign reject_reason=failed_admission?failed_reason:queue_reject_reason;
 assign raw_last=raw_valid&&actual_finish;
 assign reader_active=queue_inflight||reader_busy||token_valid||failed_admission;
 assign idle=queued_count==0&&!queue_inflight&&!reader_busy&&!token_valid&&!rejected_valid;
 replay_legality_checker legality(.task_data(lookup_task),.gsc(gsc),.current_owner_epoch(current_owner_epoch),.current_generation(current_generation),
  .current_config_id(current_config_id),.current_fir_id(current_fir_id),.current_source_epoch(current_source_epoch),
  .data_ready(data_ready&&bank_frozen),.qualified(qualified),.lease_pinned(lease_pinned),.source_stable(source_stable),.allow_aux_replay(allow_aux_replay),
  .task_profiles_valid(task_profiles_valid),.guard_clear(guard_clear),.planned_slot_clear(planned_slot_clear),
  .rf_safe(rf_safe&&clock_ok&&!hard_fault&&!abort_request),.binding_valid(binding_valid),.resources_ready(resources_ready),.time_valid(time_valid),
  .latency_validated(latency_validated),.fractional_supported(fractional_supported),.downstream_latency_ticks(downstream_latency_ticks),
  .legal(legal),.reason(legality_reason),.first_output_gsc(unused_first));
 replay_descriptor_queue #(.DEPTH(QUEUE_DEPTH)) queue(.clk(clk),.rst(rst),.push_valid(submit_valid),.push_task(submit_task),
  .push_accepted(submit_accepted),.push_rejected(submit_rejected),.push_reason(submit_reason),
  .head_valid(lookup_valid),.head_task(lookup_task),.evaluation_valid(lookup_ready),.head_legal(legal),.head_reason(legality_reason),
  .reader_ready(reader_ready&&processing_ready&&!failed_admission),.dispatch_valid(dispatch_valid),.dispatch_task(dispatch_task),
  .rejected_valid(queue_rejected_valid),.rejected_task(queue_rejected_task),.reject_reason(queue_reject_reason),.reject_ready(reject_ready&&!failed_admission),
  .retire_valid(retire),.retire_task(active_task),.retire_rejected(),.inflight(queue_inflight),.queued_count(queued_count));
 always @(posedge clk)begin
  if(rst)begin active_task<=0;failed_admission<=0;failed_reason<=0;end
  else begin
   if(dispatch_valid)active_task<=dispatch_task;
   // Defensive mismatch path: reader refused before reading, so only the queued
   // task reservation is dispositioned; no actual-RAM token is invented.
   if(reader_rejected)begin failed_admission<=1;failed_reason<=reader_reason;end
   else if(failed_admission&&reject_ready)failed_admission<=0;
  end
 end
 frozen_replay_reader reader(.clk(clk),.rst(rst),.gsc(gsc),.current_owner_epoch(current_owner_epoch),.current_generation(current_generation),
  .current_config_id(current_config_id),.current_fir_id(current_fir_id),.current_source_epoch(current_source_epoch),
  .time_valid(time_valid),.clock_ok(clock_ok),.hard_fault(hard_fault),.abort_request(runtime_abort),
  .task_valid(dispatch_valid),.task_frozen(bank_frozen),.task_qualified(qualified),.task_external_source(legal),.task_lease_pinned(lease_pinned),.latency_validated(latency_validated),
  .task_owner_epoch(dispatch_task[OWNER_EPOCH_BIT+:64]),.task_generation(dispatch_task[GENERATION_BIT+:64]),.task_id(dispatch_task[TASK_ID_BIT+:64]),
  .task_group(dispatch_task[STREAM_GROUP_ID_BIT+:32]),.task_bank(dispatch_task[BANK_ID_BIT+:32]),.task_start_ptr(dispatch_task[START_PTR_BIT+:32]),.task_count(dispatch_task[SAMPLE_COUNT_BIT+:32]),
  .task_reference_index(dispatch_task[REFERENCE_SAMPLE_INDEX_BIT+:32]),.task_config_id(dispatch_task[CONFIG_ID_BIT+:32]),.task_fir_id(dispatch_task[FIR_ID_BIT+:32]),.task_source_epoch(dispatch_task[SOURCE_EPOCH_BIT+:32]),
  .task_target_gsc(dispatch_task[TARGET_GSC_BIT+:64]),.downstream_latency_ticks(downstream_latency_ticks),.task_ready(reader_ready),
  .accepted(task_started),.rejected(reader_rejected),.reason(reader_reason),.accepted_count(),.rejected_count(),.aborted_count(),.completed_count(),.busy(reader_busy),
  .ram_en(ram_en),.ram_addr(ram_addr),.ram_group(ram_group),.ram_bank(ram_bank),.ram_response_valid(ram_response_valid),.ram_data(ram_data),
  .source_valid(raw_valid),.source_data(raw_data),.actual_start(actual_start),.actual_finish(actual_finish),.actual_start_gsc(actual_start_gsc),.actual_finish_gsc(actual_finish_gsc),.active_task_id(),
  .token_valid(token_valid),.token_ready(token_ready),.token_owner_epoch(token_owner_epoch),.token_generation(token_generation),.token_group(token_group),.token_bank(token_bank),.token_consumer(token_consumer),.token_status(token_status));
endmodule
