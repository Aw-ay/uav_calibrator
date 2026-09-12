// Combinational ABI packing. Inputs come from a valid retained aggregate.
module fault_event_encoder(input wire [255:0] snapshot,input wire [31:0] occurrences,
 input wire saturated,output reg [511:0] event_data);
 import fault_event_pkg::*;
 always @*begin
  event_data=0;
  event_data[FAULT_EVENT_TAG_OFFSET*8+:32]=FAULT_EVENT_TAG;
  event_data[FAULT_EVENT_FLAGS_OFFSET*8+:32]=saturated?FAULT_EVENT_COUNT_SATURATED:32'd0;
  event_data[FAULT_EVENT_OCCURRENCES_OFFSET*8+:32]=occurrences;
  event_data[FAULT_EVENT_SNAPSHOT_TAG_OFFSET*8+:256]=snapshot;
 end
endmodule
