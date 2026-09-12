// Event subassembly, not the instrument top. Normal producers must hold valid
// and data until ready. fault_valid denotes an RF-domain one-cycle event pulse.
module fault_event_transport #(parameter integer ADDR_W=4)(
 input wire rf_clk,ctrl_clk,rst_n,fault_valid,input wire [255:0] fault_snapshot,
 input wire normal_valid,input wire [511:0] normal_event,output wire normal_ready,
 input wire latch_head,pop,input wire [3:0] word_index,
 output wire [31:0] word_data,event_count,dropped_events,
 output wire latched_valid,command_rejected
);
 wire retained_valid,retained_ready,saturated;wire [255:0] snapshot;wire [31:0] occurrences;
 wire [511:0] encoded,merged_data;wire merged_valid,merged_ready;
 fault_event_retainer retention(.clk(rf_clk),.rst(!rst_n),.in_valid(fault_valid),.in_data(fault_snapshot),
  .out_valid(retained_valid),.out_ready(retained_ready),.out_data(snapshot),.out_occurrences(occurrences),.out_saturated(saturated));
 fault_event_encoder encoder(.snapshot(snapshot),.occurrences(occurrences),.saturated(saturated),.event_data(encoded));
 event_priority_arbiter arbiter(.clk(rf_clk),.rst(!rst_n),.fault_valid(retained_valid),.fault_data(encoded),.fault_ready(retained_ready),
  .normal_valid(normal_valid),.normal_data(normal_event),.normal_ready(normal_ready),
  .out_valid(merged_valid),.out_ready(merged_ready),.out_data(merged_data),.out_is_fault());
 // event_mailbox takes attempt pulses and counts failed attempts as drops.
 // Only signal an attempt at the actual ready/valid handshake.
 event_mailbox #(.ADDR_W(ADDR_W)) mailbox(.src_clk(rf_clk),.ctrl_clk(ctrl_clk),.rst_n(rst_n),
  .event_valid(merged_valid&&merged_ready),.event_data(merged_data),.event_ready(merged_ready),
  .dropped_events(dropped_events),.latch_head(latch_head),.pop(pop),.word_index(word_index),
  .word_data(word_data),.event_count(event_count),.latched_valid(latched_valid),.command_rejected(command_rejected));
endmodule
