// Bounded integer RAW reader. See reports/replay_reader_contract.md for edge ABI.
module frozen_replay_reader (
 input wire clk, rst,
 input wire [63:0] gsc, current_owner_epoch, current_generation,
 input wire [31:0] current_config_id, current_fir_id, current_source_epoch,
 input wire time_valid, clock_ok, hard_fault, abort_request,
 input wire task_valid, task_frozen, task_qualified, task_external_source,
 input wire task_lease_pinned, latency_validated,
 input wire [63:0] task_owner_epoch, task_generation, task_id,
 input wire [31:0] task_group, task_bank, task_start_ptr, task_count,
 input wire [31:0] task_reference_index, task_config_id, task_fir_id, task_source_epoch,
 input wire [63:0] task_target_gsc, downstream_latency_ticks,
 output wire task_ready,
 output reg accepted, rejected,
 output reg [7:0] reason,
 output reg [31:0] accepted_count, rejected_count, aborted_count, completed_count,
 output reg busy,
 output wire ram_en,
 output wire [13:0] ram_addr,
 output wire [31:0] ram_group, ram_bank,
 input wire ram_response_valid,
 input wire [63:0] ram_data,
 output wire source_valid,
 output wire [63:0] source_data,
 output reg actual_start, actual_finish,
 output reg [63:0] actual_start_gsc, actual_finish_gsc, active_task_id,
 output reg token_valid,
 input wire token_ready,
 output reg [63:0] token_owner_epoch, token_generation,
 output reg [31:0] token_group, token_bank,
 output wire [31:0] token_consumer,
 output reg [7:0] token_status
);
 localparam OK=0, BUSY=1, UNSAFE=2, UNQUALIFIED=3, CONTEXT=4,
            BOUNDS=5, LATENCY=6, TIME_RANGE=7, ALIGNMENT=8, LATE=9,
            CANCELED=10, UNDERFLOW=11, TIME_JUMP=12;
 reg [63:0] first_gsc, next_gsc, last_gsc;
 reg [31:0] count_latched, issued, consumed;
 reg [13:0] start_ptr;
 reg pending, data_valid;
 reg [63:0] data_reg;
 wire safe = time_valid && clock_ok && !hard_fault && !abort_request;
 wire context_live = current_owner_epoch == token_owner_epoch;
 wire [65:0] offset_ticks = {32'b0,task_reference_index,2'b00} + {2'b0,downstream_latency_ticks};
 wire [65:0] first_wide = {2'b0,task_target_gsc} - offset_ticks;
 wire [65:0] end_wide = first_wide + (({34'b0,task_count}-1'b1)<<2);
 wire [65:0] earliest = {2'b0,gsc}+8;
 assign task_ready = !busy && !token_valid;
 assign ram_en = busy && safe && context_live && issued<count_latched && gsc==next_gsc;
 assign ram_addr = start_ptr + issued[13:0];
 assign ram_group = token_group;
 assign ram_bank = token_bank;
 assign token_consumer = 32'd2;
 assign source_valid = data_valid && safe && context_live;
 assign source_data = source_valid ? data_reg : 64'b0;
 reg [7:0] admission;
 always @* begin
  admission=OK;
  if (!task_ready) admission=BUSY;
  else if (!safe) admission=UNSAFE;
  else if (!task_frozen || !task_qualified || !task_external_source || !task_lease_pinned) admission=UNQUALIFIED;
  else if (task_owner_epoch!=current_owner_epoch || task_generation!=current_generation || task_config_id!=current_config_id || task_fir_id!=current_fir_id || task_source_epoch!=current_source_epoch) admission=CONTEXT;
  else if (task_group<1 || task_group>4 || task_bank>3 || task_start_ptr>16383 || task_count<1 || task_count>16384 || task_reference_index>=task_count) admission=BOUNDS;
  else if (!latency_validated) admission=LATENCY;
  else if (offset_ticks>{2'b0,task_target_gsc} || end_wide[65:64]!=0 || earliest[65:64]!=0) admission=TIME_RANGE;
  else if (first_wide[1:0]!=gsc[1:0]) admission=ALIGNMENT;
  else if (first_wide<earliest) admission=LATE;
 end
 always @(posedge clk) begin
  if (rst) begin
   busy<=0; token_valid<=0; accepted<=0; rejected<=0; reason<=0;
   accepted_count<=0; rejected_count<=0; aborted_count<=0; completed_count<=0;
   pending<=0; data_valid<=0; data_reg<=0; actual_start<=0; actual_finish<=0;
   actual_start_gsc<=0; actual_finish_gsc<=0; active_task_id<=0;
   token_owner_epoch<=0; token_generation<=0; token_group<=0; token_bank<=0; token_status<=0;
   first_gsc<=0; next_gsc<=0; last_gsc<=0; count_latched<=0; issued<=0; consumed<=0; start_ptr<=0;
  end else begin
   accepted<=0; rejected<=0; actual_start<=0; actual_finish<=0; data_valid<=0; data_reg<=0;
   pending<=ram_en;
   if (token_valid && token_ready) token_valid<=0;
   if (task_valid) begin
    if (admission!=OK) begin rejected<=1; reason<=admission; rejected_count<=rejected_count+1; end
    else begin
     accepted<=1; reason<=OK; accepted_count<=accepted_count+1; busy<=1;
     token_owner_epoch<=task_owner_epoch; token_generation<=task_generation;
     token_group<=task_group; token_bank<=task_bank; active_task_id<=task_id;
     count_latched<=task_count; start_ptr<=task_start_ptr[13:0]; issued<=0; consumed<=0;
     first_gsc<=first_wide[63:0]; next_gsc<=first_wide[63:0]-4;
     last_gsc<=gsc;
    end
   end
   if (busy) begin
    last_gsc<=gsc;
    if (!safe || !context_live || gsc!=last_gsc+4 || (pending && !ram_response_valid)) begin
     // One-cycle fixed RAM: pending response is consumed/discarded at this edge.
     // ram_en may already have been accepted on a time jump/underflow edge;
     // retain busy one more edge to discard that final in-flight response.
     if (ram_en) begin
      count_latched<=issued; // suppress further reads, drain pending next edge
      consumed<=32'hffffffff;
     end else begin
      busy<=0; token_valid<=1; aborted_count<=aborted_count+1;
     end
     token_status<= !safe || !context_live ? CANCELED : (gsc!=last_gsc+4 ? TIME_JUMP : UNDERFLOW);
     reason<= !safe || !context_live ? CANCELED : (gsc!=last_gsc+4 ? TIME_JUMP : UNDERFLOW);
    end else if (consumed==32'hffffffff) begin
     busy<=0; token_valid<=1; aborted_count<=aborted_count+1;
    end else begin
     if (ram_en) begin issued<=issued+1; next_gsc<=next_gsc+4; end
     if (pending) begin
      data_valid<=1; data_reg<=ram_data; consumed<=consumed+1;
      if (consumed==0) begin actual_start<=1; actual_start_gsc<=gsc; end
      if (consumed+1==count_latched) begin
       actual_finish<=1; actual_finish_gsc<=gsc; busy<=0;
       token_valid<=1; token_status<=OK; completed_count<=completed_count+1;
      end
     end
    end
   end
  end
 end
endmodule
