// RF-domain transaction executor. Per-module actions retire on actual outcomes.
module instrument_command_executor(
 input wire clk,rst,cmd_valid,output wire cmd_ready,input wire [15:0] cmd_opcode,cmd_words,
 input wire [8191:0] cmd_payload,input wire safe_config,candidate_valid,acquisition_ready,binding_valid,
 output reg result_valid,input wire result_ready,output reg [7:0] result_code,
 output reg [15:0] result_words,output reg [8191:0] result_payload,
 output reg [8191:0] config_image,output reg config_loaded,run_enable,rf_arm,rf_request,reset_request,
 output reg action_valid,output reg [15:0] action_opcode,output reg [8191:0] action_payload,
 input wire outcome_valid,input wire [7:0] outcome_code,input wire [15:0] outcome_words,input wire [8191:0] outcome_payload
);
 import instrument_control_pkg::*;
 reg waiting;reg length_ok;
 assign cmd_ready=!rst&&!waiting&&!result_valid;
 always @*begin
  length_ok=0;
  case(cmd_opcode)
    CMD_CONFIG:length_ok=cmd_words==CMD_CONFIG_WORDS;
    CMD_FINE_PDW_PEEK:length_ok=cmd_words==CMD_FINE_PDW_PEEK_WORDS;
    CMD_FINE_PDW_POP:length_ok=cmd_words==CMD_FINE_PDW_POP_WORDS;
    CMD_AUX_CAPTURE:length_ok=cmd_words==CMD_AUX_CAPTURE_WORDS;
    CMD_AUX_META_PEEK:length_ok=cmd_words==CMD_AUX_META_PEEK_WORDS;
    CMD_AUX_META_POP:length_ok=cmd_words==CMD_AUX_META_POP_WORDS;
    CMD_ARM:length_ok=cmd_words==CMD_ARM_WORDS;
    CMD_STOP:length_ok=cmd_words==CMD_STOP_WORDS;
    CMD_RESET:length_ok=cmd_words==CMD_RESET_WORDS;
    CMD_RF_REQUEST:length_ok=cmd_words==CMD_RF_REQUEST_WORDS;
    CMD_MODE:length_ok=cmd_words==CMD_MODE_WORDS;
    CMD_RX_PROFILE:length_ok=cmd_words==CMD_RX_PROFILE_WORDS;
    CMD_TX_PROFILE:length_ok=cmd_words==CMD_TX_PROFILE_WORDS;
    CMD_REPLAY:length_ok=cmd_words==CMD_REPLAY_WORDS;
    CMD_DDS:length_ok=cmd_words==CMD_DDS_WORDS;
    CMD_AWG_LOAD:length_ok=cmd_words==CMD_AWG_LOAD_WORDS;
    CMD_AWG_PLAY:length_ok=cmd_words==CMD_AWG_PLAY_WORDS;
    CMD_RF_FAULT_PEEK:length_ok=cmd_words==CMD_RF_FAULT_PEEK_WORDS;
    CMD_RF_FAULT_POP:length_ok=cmd_words==CMD_RF_FAULT_POP_WORDS;
    CMD_SOURCE_EVENT_PEEK:length_ok=cmd_words==CMD_SOURCE_EVENT_PEEK_WORDS;
    CMD_SOURCE_EVENT_POP:length_ok=cmd_words==CMD_SOURCE_EVENT_POP_WORDS;
    CMD_PDW_PEEK:length_ok=cmd_words==CMD_PDW_PEEK_WORDS;
    CMD_PDW_POP:length_ok=cmd_words==CMD_PDW_POP_WORDS;
    CMD_STATUS:length_ok=cmd_words==CMD_STATUS_WORDS;
    CMD_REJECT_POP:length_ok=cmd_words==CMD_REJECT_POP_WORDS;
    CMD_PRODUCER_ERROR_POP:length_ok=cmd_words==CMD_PRODUCER_ERROR_POP_WORDS;
    default:length_ok=0;
  endcase
 end
 always @(posedge clk)begin
  if(rst)begin
   waiting<=0;result_valid<=0;result_code<=0;result_words<=0;result_payload<=0;
   config_image<=0;config_loaded<=0;run_enable<=0;rf_arm<=0;rf_request<=0;reset_request<=0;
   action_valid<=0;action_opcode<=0;action_payload<=0;
  end else begin
   action_valid<=0;
   if(result_valid&&result_ready)result_valid<=0;
   if(waiting&&outcome_valid)begin
    waiting<=0;result_valid<=1;result_code<=outcome_code;result_words<=outcome_words;result_payload<=outcome_payload;
    if(action_opcode==CMD_RESET)reset_request<=0;
   end
   if(cmd_valid&&cmd_ready)begin
    result_code<=0;result_words<=0;result_payload<=0;
    if(!length_ok)begin result_valid<=1;result_code<=2;end
    else case(cmd_opcode)
     CMD_CONFIG:begin
      result_valid<=1;
      if(!safe_config||run_enable||rf_arm)result_code<=3;
      else if(!candidate_valid)result_code<=2;
      else begin config_image<=cmd_payload;config_loaded<=1;end
     end
     CMD_ARM:begin
      result_valid<=1;
      if(!config_loaded||!acquisition_ready||reset_request)result_code<=3;
      else run_enable<=1;
     end
     CMD_STOP:begin run_enable<=0;rf_arm<=0;rf_request<=0;result_valid<=1;end
     CMD_RF_REQUEST:begin
      result_valid<=1;
      if(cmd_payload[31:3]!=0||(cmd_payload[2]&&cmd_payload[0])||(cmd_payload[1]&&!cmd_payload[0]))result_code<=2;
      else if((|cmd_payload[1:0])&&!binding_valid)result_code<=5;
      else begin rf_arm<=cmd_payload[0];rf_request<=cmd_payload[1];action_valid<=1;action_opcode<=cmd_opcode;action_payload<=cmd_payload;end
     end
     default:begin
      if(!config_loaded&&cmd_opcode!=CMD_FINE_PDW_PEEK&&cmd_opcode!=CMD_FINE_PDW_POP&&cmd_opcode!=CMD_STATUS&&cmd_opcode!=CMD_RESET&&cmd_opcode!=CMD_PDW_PEEK&&cmd_opcode!=CMD_PDW_POP&&cmd_opcode!=CMD_SOURCE_EVENT_PEEK&&cmd_opcode!=CMD_SOURCE_EVENT_POP&&cmd_opcode!=CMD_RF_FAULT_PEEK&&cmd_opcode!=CMD_RF_FAULT_POP)begin result_valid<=1;result_code<=3;end
      else begin
       waiting<=1;action_valid<=1;action_opcode<=cmd_opcode;action_payload<=cmd_payload;
       if(cmd_opcode==CMD_RESET)begin reset_request<=1;run_enable<=0;rf_arm<=0;rf_request<=0;end
      end
     end
    endcase
   end
  end
 end
endmodule
