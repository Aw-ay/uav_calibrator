// Generated from contracts/command_gateway.json
package command_gateway_pkg;
 localparam [31:0] GW_ID=32'h00004000;
 localparam [31:0] GW_STATUS=32'h00004004;
 localparam [31:0] GW_OP_LENGTH=32'h00004008;
 localparam [31:0] GW_SEQUENCE=32'h0000400c;
 localparam [31:0] GW_CRC32C=32'h00004010;
 localparam [31:0] GW_SUBMIT=32'h00004014;
 localparam [31:0] GW_DONE_SEQUENCE=32'h00004018;
 localparam [31:0] GW_RESULT_LENGTH=32'h0000401c;
 localparam [31:0] GW_PAYLOAD=32'h00004400;
 localparam [31:0] GW_RESULT=32'h00004800;
 localparam [31:0] GW_IRQ_ENABLE=32'h00004020;
 localparam [31:0] GW_IRQ_STATUS=32'h00004024;
 localparam [31:0] GW_IRQ_COMMAND_DONE=32'h00000001;
 localparam [31:0] GW_IRQ_PDW_AVAILABLE=32'h00000002;
 localparam [31:0] GW_IRQ_SOURCE_EVENT_AVAILABLE=32'h00000004;
 localparam [31:0] GW_IRQ_RF_FAULT_AVAILABLE=32'h00000008;
 localparam [31:0] GW_IRQ_UNIFIED_EVENT_AVAILABLE=32'h00000010;
 localparam [31:0] GW_IRQ_RESET_ENABLE=32'h00000001;
 localparam [31:0] GW_ID_VALUE=32'h434d4431;
 localparam integer GW_WORDS=256;
endpackage
