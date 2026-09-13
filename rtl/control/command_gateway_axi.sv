// Ordered PS transaction transport. Completion means RF execution response,
// not request CDC capture. One in flight, stable response until next completion.
module command_gateway_axi(
 input wire ctrl_clk,rf_clk,rst_n,input wire pdw_available_rf,source_event_available_rf,rf_fault_available_rf,
 input wire [31:0] unified_event_count,unified_event_word,unified_event_dropped,
 input wire unified_event_latched,
 output wire unified_event_latch,unified_event_pop,output wire [3:0] unified_event_word_index,
 input wire [31:0] s_axi_awaddr,input wire s_axi_awvalid,output wire s_axi_awready,
 input wire [31:0] s_axi_wdata,input wire [3:0] s_axi_wstrb,input wire s_axi_wvalid,output wire s_axi_wready,
 output reg [1:0] s_axi_bresp,output reg s_axi_bvalid,input wire s_axi_bready,
 input wire [31:0] s_axi_araddr,input wire s_axi_arvalid,output wire s_axi_arready,
 output reg [31:0] s_axi_rdata,output reg [1:0] s_axi_rresp,output reg s_axi_rvalid,input wire s_axi_rready,
 output wire cmd_valid,input wire cmd_ready,output wire [15:0] cmd_opcode,cmd_words,
 output wire [31:0] cmd_sequence,output wire [8191:0] cmd_payload,
 input wire result_valid,output wire result_ready,input wire [7:0] result_code,
 input wire [15:0] result_words,input wire [8191:0] result_payload,output wire irq
);
 import command_gateway_pkg::*;
 import calibrator_contract_pkg::*;
 reg aw_full,w_full;reg [31:0] awaddr,wdata;reg [3:0] wstrb;
 reg [8191:0] shadow,frozen_payload,response_payload;
 reg [31:0] header,sequence_reg,expected_crc,frozen_header,frozen_sequence,frozen_crc,crc;
 reg [8:0] scan_index;reg [1:0] state;localparam IDLE=0,CHECK=1,WAIT_RESPONSE=2;
 reg done;reg [7:0] status_code;reg [31:0] done_sequence;reg [15:0] response_words;
 reg send_request;wire request_busy,request_valid,request_take;wire [8255:0] request_data;
 wire response_valid,response_take,response_busy;wire [8247:0] response_data;
 reg [8255:0] command_hold;reg command_pending,executing;
 wire [31:0] mask={{8{wstrb[3]}},{8{wstrb[2]}},{8{wstrb[1]}},{8{wstrb[0]}}};
 wire [31:0] action=wdata&mask;
 wire execute=aw_full&&w_full&&!s_axi_bvalid;
 assign unified_event_latch=execute&&awaddr==REG_EVENT_LATCH&&action==1&&unified_event_count!=0;
 assign unified_event_pop=execute&&awaddr==REG_EVENT_POP&&action==1&&unified_event_latched;
 assign unified_event_word_index=s_axi_araddr[5:2];
 function automatic [31:0] crc_word(input [31:0] initial_crc,word_value);
  reg [31:0] c;integer k;begin c=initial_crc;for(k=0;k<32;k=k+1)c=(c>>1)^((c[0]^word_value[k])?32'h82f63b78:32'd0);crc_word=c;end
 endfunction
 assign s_axi_awready=!aw_full&&!s_axi_bvalid;
 assign s_axi_wready=!w_full&&!s_axi_bvalid;
 assign s_axi_arready=!s_axi_rvalid;
 // The source level is registered in RF; no multi-bit count crosses domains.
 (* ASYNC_REG="TRUE" *) reg pdw_meta,pdw_sync;
 (* ASYNC_REG="TRUE" *) reg source_event_meta,source_event_sync;
 (* ASYNC_REG="TRUE" *) reg rf_fault_meta,rf_fault_sync;
 reg [31:0] irq_enable;
 wire [31:0] irq_status=(done?GW_IRQ_COMMAND_DONE:0)|(pdw_sync?GW_IRQ_PDW_AVAILABLE:0)|(source_event_sync?GW_IRQ_SOURCE_EVENT_AVAILABLE:0)|(rf_fault_sync?GW_IRQ_RF_FAULT_AVAILABLE:0)|(unified_event_count!=0?GW_IRQ_UNIFIED_EVENT_AVAILABLE:0);
 wire [31:0] irq_enable_next=(irq_enable&~mask)|action;
 assign irq=rst_n&&|(irq_status&irq_enable);
 always @(posedge ctrl_clk or negedge rst_n)begin
  if(!rst_n)begin pdw_meta<=0;pdw_sync<=0;source_event_meta<=0;source_event_sync<=0;rf_fault_meta<=0;rf_fault_sync<=0;end
  else begin pdw_meta<=pdw_available_rf;pdw_sync<=pdw_meta;source_event_meta<=source_event_available_rf;source_event_sync<=source_event_meta;rf_fault_meta<=rf_fault_available_rf;rf_fault_sync<=rf_fault_meta;end
 end
 assign cmd_valid=command_pending;
 assign cmd_payload=command_hold[8191:0];assign cmd_opcode=command_hold[8192+:16];
 assign cmd_words=command_hold[8208+:16];assign cmd_sequence=command_hold[8224+:32];
 assign request_take=request_valid&&!command_pending&&!executing;
 assign result_ready=executing&&!response_busy;
 assign response_take=response_valid&&state==WAIT_RESPONSE;
 cdc_mailbox #(.WIDTH(8256)) request_box(.src_clk(ctrl_clk),.dst_clk(rf_clk),.rst_n(rst_n),
  .src_send(send_request),.src_data({frozen_sequence,frozen_header,frozen_payload}),.src_busy(request_busy),.src_done(),
  .dst_valid(request_valid),.dst_data(request_data),.dst_take(request_take));
 cdc_mailbox #(.WIDTH(8248)) response_box(.src_clk(rf_clk),.dst_clk(ctrl_clk),.rst_n(rst_n),
  .src_send(result_valid&&result_ready),.src_data({cmd_sequence,result_words,result_code,result_payload}),.src_busy(response_busy),.src_done(),
  .dst_valid(response_valid),.dst_data(response_data),.dst_take(response_take));
 always @(posedge rf_clk or negedge rst_n)begin
  if(!rst_n)begin command_hold<=0;command_pending<=0;executing<=0;end
  else begin
   if(request_take)begin command_hold<=request_data;command_pending<=1;end
   if(cmd_valid&&cmd_ready)begin command_pending<=0;executing<=1;end
   if(result_valid&&result_ready)executing<=0;
  end
 end
 always @(posedge ctrl_clk or negedge rst_n)begin
  if(!rst_n)begin
   aw_full<=0;w_full<=0;awaddr<=0;wdata<=0;wstrb<=0;s_axi_bresp<=0;s_axi_bvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;s_axi_rvalid<=0;
   shadow<=0;frozen_payload<=0;response_payload<=0;header<=0;sequence_reg<=0;expected_crc<=0;
   frozen_header<=0;frozen_sequence<=0;frozen_crc<=0;crc<=0;scan_index<=0;state<=IDLE;
   irq_enable<=GW_IRQ_RESET_ENABLE;done<=0;status_code<=0;done_sequence<=0;response_words<=0;send_request<=0;
  end else begin
   send_request<=0;
   if(s_axi_awvalid&&s_axi_awready)begin aw_full<=1;awaddr<=s_axi_awaddr;end
   if(s_axi_wvalid&&s_axi_wready)begin w_full<=1;wdata<=s_axi_wdata;wstrb<=s_axi_wstrb;end
   if(s_axi_bvalid&&s_axi_bready)s_axi_bvalid<=0;
   if(s_axi_rvalid&&s_axi_rready)s_axi_rvalid<=0;
   if(state==CHECK)begin
    if(scan_index==frozen_header[31:16])begin
     if((~crc)!=frozen_crc)begin state<=IDLE;done<=1;status_code<=1;done_sequence<=frozen_sequence;response_words<=0;response_payload<=0;end
     else begin send_request<=1;state<=WAIT_RESPONSE;end
    end else begin crc<=crc_word(crc,frozen_payload[scan_index*32+:32]);scan_index<=scan_index+1'b1;end
   end
   if(response_take)begin
    {done_sequence,response_words,status_code,response_payload}<=response_data;done<=1;state<=IDLE;
   end
   if(execute)begin
    aw_full<=0;w_full<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
    if(awaddr[1:0]!=0)s_axi_bresp<=2;
    else if(awaddr>=GW_PAYLOAD&&awaddr<GW_PAYLOAD+GW_WORDS*4)
     shadow[((awaddr-GW_PAYLOAD)>>2)*32+:32]<=(shadow[((awaddr-GW_PAYLOAD)>>2)*32+:32]&~mask)|action;
    else case(awaddr)
     REG_EVENT_LATCH:if(action!=1||unified_event_count==0)s_axi_bresp<=2;
     REG_EVENT_POP:if(action!=1||!unified_event_latched)s_axi_bresp<=2;
     GW_IRQ_ENABLE:if((irq_enable_next&~(GW_IRQ_COMMAND_DONE|GW_IRQ_PDW_AVAILABLE|GW_IRQ_SOURCE_EVENT_AVAILABLE|GW_IRQ_RF_FAULT_AVAILABLE|GW_IRQ_UNIFIED_EVENT_AVAILABLE))!=0)s_axi_bresp<=2;else irq_enable<=irq_enable_next;
     GW_OP_LENGTH:header<=(header&~mask)|action;
     GW_SEQUENCE:sequence_reg<=(sequence_reg&~mask)|action;
     GW_CRC32C:expected_crc<=(expected_crc&~mask)|action;
     GW_STATUS:if(action==2)done<=0;else s_axi_bresp<=2;
     GW_SUBMIT:if(action!=1||state!=IDLE||request_busy||header[31:16]>GW_WORDS)s_axi_bresp<=2;
      else begin
       frozen_payload<=shadow;frozen_header<=header;frozen_sequence<=sequence_reg;frozen_crc<=expected_crc;
       crc<=crc_word(crc_word(32'hffffffff,header),sequence_reg);scan_index<=0;state<=CHECK;done<=0;status_code<=0;
      end
     default:s_axi_bresp<=2;
    endcase
   end
   if(s_axi_arvalid&&s_axi_arready)begin
    s_axi_rvalid<=1;s_axi_rresp<=0;s_axi_rdata<=0;
    if(s_axi_araddr[1:0]!=0)s_axi_rresp<=2;
    else if(s_axi_araddr>=GW_PAYLOAD&&s_axi_araddr<GW_PAYLOAD+GW_WORDS*4)s_axi_rdata<=shadow[((s_axi_araddr-GW_PAYLOAD)>>2)*32+:32];
    else if(s_axi_araddr>=GW_RESULT&&s_axi_araddr<GW_RESULT+GW_WORDS*4)s_axi_rdata<=response_payload[((s_axi_araddr-GW_RESULT)>>2)*32+:32];
    else if(s_axi_araddr>=REG_EVENT_WORD_0&&s_axi_araddr<=REG_EVENT_WORD_15)begin
     if(unified_event_latched)s_axi_rdata<=unified_event_word;else s_axi_rresp<=2;
    end
    else case(s_axi_araddr)
     REG_EVENT_COUNT:s_axi_rdata<=unified_event_count;
     REG_DROP_EVENT:s_axi_rdata<=unified_event_dropped;
     GW_ID:s_axi_rdata<=GW_ID_VALUE;
     GW_IRQ_ENABLE:s_axi_rdata<=irq_enable;
     GW_IRQ_STATUS:s_axi_rdata<=irq_status;
     GW_STATUS:s_axi_rdata<={16'd0,status_code,5'd0,(status_code!=0),done,(state!=IDLE)};
     GW_OP_LENGTH:s_axi_rdata<=header;
     GW_SEQUENCE:s_axi_rdata<=sequence_reg;
     GW_CRC32C:s_axi_rdata<=expected_crc;
     GW_DONE_SEQUENCE:s_axi_rdata<=done_sequence;
     GW_RESULT_LENGTH:s_axi_rdata<={16'd0,response_words};
     default:s_axi_rresp<=2;
    endcase
   end
  end
 end
endmodule
