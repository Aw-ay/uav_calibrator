// Generated from contracts/event_format.json
package capture_event_pkg;
 localparam logic [31:0] EVENT_BYTES=32'd64;
 localparam logic [31:0] EVENT_CAPTURE_TAG=32'd65537;
 localparam logic [31:0] EVENT_TAG_OFFSET=32'd0;
 localparam logic [31:0] EVENT_FLAGS_OFFSET=32'd4;
 localparam logic [31:0] EVENT_PULSE_ID_OFFSET=32'd8;
 localparam logic [31:0] EVENT_OWNER_EPOCH_OFFSET=32'd16;
 localparam logic [31:0] EVENT_CONFIG_ID_OFFSET=32'd24;
 localparam logic [31:0] EVENT_TOA_GSC_OFFSET=32'd28;
 localparam logic [31:0] EVENT_WIDTH_TICKS_OFFSET=32'd36;
 localparam logic [31:0] EVENT_PEAK_POWER_OFFSET=32'd40;
 localparam logic [31:0] EVENT_ENERGY_SUM_OFFSET=32'd44;
 localparam logic [31:0] EVENT_SELECTED_RANGE_OFFSET=32'd52;
 localparam logic [31:0] EVENT_RESERVED_OFFSET=32'd56;
 localparam logic [31:0] EVENT_TOA_VALID=32'd1;
 localparam logic [31:0] EVENT_WIDTH_VALID=32'd2;
 localparam logic [31:0] EVENT_PEAK_VALID=32'd4;
 localparam logic [31:0] EVENT_ENERGY_VALID=32'd8;
 localparam logic [31:0] EVENT_SELECTED_VALID=32'd16;
endpackage
