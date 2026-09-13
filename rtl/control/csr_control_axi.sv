module csr_control_axi #(
 parameter [31:0] BUILD_ID=0,
 parameter integer UNIFIED_EVENTS=0,EVENT_ADDR_W=4
)(input wire ctrl_clk,rf_clk,rst_n,
 input wire [31:0] s_axi_awaddr,input wire s_axi_awvalid,output wire s_axi_awready,
 input wire [31:0] s_axi_wdata,input wire [3:0] s_axi_wstrb,input wire s_axi_wvalid,output wire s_axi_wready,
 output reg [1:0] s_axi_bresp,output reg s_axi_bvalid,input wire s_axi_bready,
 input wire [31:0] s_axi_araddr,input wire s_axi_arvalid,output wire s_axi_arready,
 output reg [31:0] s_axi_rdata,output reg [1:0] s_axi_rresp,output reg s_axi_rvalid,input wire s_axi_rready,
 input wire rf_safe_boundary,calibration_valid,input wire [31:0] fault_set,
 // Legacy mode: event attempt pulses. Unified mode: hold normal valid/data until ready.
 input wire rf_event_valid,input wire [511:0] rf_event_data,
 // RF-domain fault observation pulse and logical snapshot; ignored in legacy mode.
 input wire rf_fault_valid,input wire [255:0] rf_fault_snapshot,
 output wire rf_event_ready,output wire [31:0] rf_event_dropped,
 output reg [31:0] active_mode,active_config_id,active_pre,active_post,active_max_pulse,active_eop_hold,active_detector_latency,
 output reg armed,output wire tx_enable,irq,output wire [63:0] gsc);
 import calibrator_contract_pkg::*;
 // Extension bitfields: contracts/control_implementation.json.
 localparam [31:0] REQUEST_ARM=1,REQUEST_STOP=2,REQUEST_SNAPSHOT=4;
 reg aw_full,w_full;reg [31:0] awaddr,wdata;reg [3:0] wstrb;
 reg [31:0] shadow_mode,shadow_id,shadow_pre,shadow_post,shadow_max,shadow_hold,shadow_latency;
 reg [31:0] faults,irq_enable,ack_id,ack_mode,ack_latency;
 reg commit_send,commit_pending,commit_rejected;reg [223:0] commit_payload;
 wire commit_busy,commit_done,commit_valid;wire [223:0] rf_config;
 reg snapshot_send,snapshot_pending,snapshot_valid;reg [29:0] snapshot_sequence;wire snapshot_busy,snapshot_done,snapshot_request;
 wire unused_data;reg [63:0] snapshot_hold,snapshot_value;
 wire [31:0] mask={{8{wstrb[3]}},{8{wstrb[2]}},{8{wstrb[1]}},{8{wstrb[0]}}};
 wire [31:0] action=wdata&mask;
 wire execute=aw_full&&w_full&&!s_axi_bvalid;
 wire [31:0] event_count,event_word;
 wire event_latched;
 wire event_latch=execute&&awaddr==REG_EVENT_LATCH&&action==1&&event_count!=0;
 wire event_pop=execute&&awaddr==REG_EVENT_POP&&action==1&&event_latched;
 generate if(UNIFIED_EVENTS)begin : unified_events
 fault_event_transport #(.ADDR_W(EVENT_ADDR_W)) events(
  .rf_clk(rf_clk),.ctrl_clk(ctrl_clk),.rst_n(rst_n),
  .fault_valid(rf_fault_valid),.fault_snapshot(rf_fault_snapshot),
  .normal_valid(rf_event_valid),.normal_event(rf_event_data),.normal_ready(rf_event_ready),
  .dropped_events(rf_event_dropped),.latch_head(event_latch),.pop(event_pop),
  .word_index(s_axi_araddr[5:2]),.word_data(event_word),.event_count(event_count),
  .latched_valid(event_latched),.command_rejected());
 end else begin : legacy_events
 event_mailbox #(.ADDR_W(EVENT_ADDR_W)) events(.src_clk(rf_clk),.ctrl_clk(ctrl_clk),.rst_n(rst_n),
  .event_valid(rf_event_valid),.event_data(rf_event_data),.event_ready(rf_event_ready),.dropped_events(rf_event_dropped),
  .latch_head(event_latch),.pop(event_pop),.word_index(s_axi_araddr[5:2]),.word_data(event_word),
  .event_count(event_count),.latched_valid(event_latched),.command_rejected());
 end endgenerate
 wire [31:0] clear_faults=(execute&&awaddr==REG_FAULT_STATUS)?action:0;
 assign s_axi_awready=!aw_full&&!s_axi_bvalid;
 assign s_axi_wready=!w_full&&!s_axi_bvalid;
 assign s_axi_arready=!s_axi_rvalid;
 assign tx_enable=1'b0; assign irq=|(faults&irq_enable);
 function automatic [31:0] merge(input [31:0] old_value);merge=(old_value&~mask)|action;endfunction
 cdc_mailbox #(.WIDTH(224)) config_mailbox(.src_clk(ctrl_clk),.dst_clk(rf_clk),.rst_n(rst_n),.src_send(commit_send),.src_data(commit_payload),.src_busy(commit_busy),.src_done(commit_done),.dst_valid(commit_valid),.dst_data(rf_config),.dst_take(rf_safe_boundary));
 cdc_mailbox #(.WIDTH(1)) snapshot_mailbox(.src_clk(ctrl_clk),.dst_clk(rf_clk),.rst_n(rst_n),.src_send(snapshot_send),.src_data(1'b0),.src_busy(snapshot_busy),.src_done(snapshot_done),.dst_valid(snapshot_request),.dst_data(unused_data),.dst_take(1'b1));
 gsc_timebase timebase(.rf_clk(rf_clk),.rst_n(rst_n),.gsc(gsc));
 always @(posedge rf_clk or negedge rst_n)begin
  if(!rst_n)begin active_mode<=0;active_config_id<=0;active_pre<=REG_PRE_SAMPLES_SHADOW_RESET;active_post<=REG_POST_SAMPLES_SHADOW_RESET;active_max_pulse<=REG_MAX_PULSE_SAMPLES_SHADOW_RESET;active_eop_hold<=REG_EOP_HOLD_SAMPLES_SHADOW_RESET;active_detector_latency<=0;snapshot_hold<=0;end
  else begin
   if(commit_valid&&rf_safe_boundary){active_mode,active_config_id,active_pre,active_post,active_max_pulse,active_eop_hold,active_detector_latency}<=rf_config;
   if(snapshot_request)snapshot_hold<=gsc;
  end
 end
 always @(posedge ctrl_clk or negedge rst_n)begin
  if(!rst_n)begin
   aw_full<=0;w_full<=0;awaddr<=0;wdata<=0;wstrb<=0;s_axi_bvalid<=0;s_axi_bresp<=0;s_axi_rvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;
   shadow_mode<=0;shadow_id<=0;shadow_pre<=REG_PRE_SAMPLES_SHADOW_RESET;shadow_post<=REG_POST_SAMPLES_SHADOW_RESET;shadow_max<=REG_MAX_PULSE_SAMPLES_SHADOW_RESET;shadow_hold<=REG_EOP_HOLD_SAMPLES_SHADOW_RESET;shadow_latency<=0;
   faults<=0;irq_enable<=0;armed<=0;ack_id<=0;ack_mode<=0;ack_latency<=0;commit_send<=0;commit_pending<=0;commit_rejected<=0;commit_payload<=0;snapshot_send<=0;snapshot_pending<=0;snapshot_value<=0;snapshot_valid<=0;snapshot_sequence<=0;
  end else begin
   commit_send<=0;snapshot_send<=0;faults<=(faults&~clear_faults)|fault_set;
   if(|fault_set||!calibration_valid)armed<=0;
   if(commit_done)begin commit_pending<=0;ack_mode<=commit_payload[223:192];ack_id<=commit_payload[191:160];ack_latency<=commit_payload[31:0];end
   if(snapshot_done)begin snapshot_pending<=0;snapshot_value<=snapshot_hold;snapshot_valid<=1;snapshot_sequence<=snapshot_sequence+1'b1;end
   if(s_axi_awvalid&&s_axi_awready)begin aw_full<=1;awaddr<=s_axi_awaddr;end
   if(s_axi_wvalid&&s_axi_wready)begin w_full<=1;wdata<=s_axi_wdata;wstrb<=s_axi_wstrb;end
   if(s_axi_bvalid&&s_axi_bready)s_axi_bvalid<=0;
   if(s_axi_rvalid&&s_axi_rready)s_axi_rvalid<=0;
   if(execute)begin
    aw_full<=0;w_full<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
    case(awaddr)
     REG_EVENT_LATCH:if(action!=1||event_count==0)s_axi_bresp<=2;
     REG_EVENT_POP:if(action!=1||!event_latched)s_axi_bresp<=2;
     REG_FAULT_STATUS:begin end
     REG_IRQ_ENABLE:irq_enable<=merge(irq_enable);
     REG_SHADOW_MODE:shadow_mode<=merge(shadow_mode);
     REG_SHADOW_CONFIG_ID:shadow_id<=merge(shadow_id);
     REG_PRE_SAMPLES_SHADOW:shadow_pre<=merge(shadow_pre);
     REG_POST_SAMPLES_SHADOW:shadow_post<=merge(shadow_post);
     REG_MAX_PULSE_SAMPLES_SHADOW:shadow_max<=merge(shadow_max);
     REG_EOP_HOLD_SAMPLES_SHADOW:shadow_hold<=merge(shadow_hold);
     REG_DETECTOR_LATENCY_BOUND_SHADOW:shadow_latency<=merge(shadow_latency);
     REG_COMMIT:if(action!=0)begin
      if(action!=1||commit_pending||armed||shadow_mode>1||shadow_max==0||({2'b0,shadow_pre}+{2'b0,shadow_post}+{2'b0,shadow_max})>SYS_CAPTURE_SAMPLES_PER_BANK)begin s_axi_bresp<=2;commit_rejected<=1;end
      else begin commit_payload<={shadow_mode,shadow_id,shadow_pre,shadow_post,shadow_max,shadow_hold,shadow_latency};commit_send<=1;commit_pending<=1;commit_rejected<=0;end
     end
     REG_REQUEST:case(action)
      0:begin end
      REQUEST_STOP:armed<=0;
      REQUEST_ARM:if(commit_pending||ack_mode!=1||ack_latency==0||!calibration_valid||faults!=0||fault_set!=0)s_axi_bresp<=2;else armed<=1;
      REQUEST_SNAPSHOT:if(snapshot_pending)s_axi_bresp<=2;else begin snapshot_send<=1;snapshot_pending<=1;end
      default:s_axi_bresp<=2;
     endcase
     default:s_axi_bresp<=2;
    endcase
   end
   if(s_axi_arvalid&&s_axi_arready)begin
    s_axi_rvalid<=1;s_axi_rresp<=0;s_axi_rdata<=0;
    case(s_axi_araddr)
     REG_EVENT_COUNT:s_axi_rdata<=event_count;
     REG_IP_ID:s_axi_rdata<=REG_IP_ID_RESET;
     REG_ABI_VERSION:s_axi_rdata<=REG_ABI_VERSION_RESET;
     REG_BUILD_ID:s_axi_rdata<=BUILD_ID;
     REG_CAPABILITIES:s_axi_rdata<=0;
     REG_STATE:s_axi_rdata<={31'b0,armed};
     REG_FAULT_STATUS:s_axi_rdata<=faults;
     REG_IRQ_ENABLE:s_axi_rdata<=irq_enable;
     REG_IRQ_STATUS:s_axi_rdata<=faults;
     REG_SHADOW_MODE:s_axi_rdata<=shadow_mode;
     REG_SHADOW_CONFIG_ID:s_axi_rdata<=shadow_id;
     REG_PRE_SAMPLES_SHADOW:s_axi_rdata<=shadow_pre;
     REG_POST_SAMPLES_SHADOW:s_axi_rdata<=shadow_post;
     REG_MAX_PULSE_SAMPLES_SHADOW:s_axi_rdata<=shadow_max;
     REG_EOP_HOLD_SAMPLES_SHADOW:s_axi_rdata<=shadow_hold;
     REG_DETECTOR_LATENCY_BOUND_SHADOW:s_axi_rdata<=shadow_latency;
     REG_ACTIVE_CONFIG_ID:s_axi_rdata<=ack_id;
     REG_COMMIT_STATUS:s_axi_rdata<={30'b0,commit_rejected,commit_pending};
     32'h0210:s_axi_rdata<={snapshot_sequence,snapshot_valid,snapshot_pending};
     REG_GSC_SNAPSHOT_LO:s_axi_rdata<=snapshot_value[31:0];
     REG_GSC_SNAPSHOT_HI:s_axi_rdata<=snapshot_value[63:32];
     REG_EPOCH_ID,REG_TIME_QUALITY:s_axi_rdata<=0;
     REG_GSC_STRIDE:s_axi_rdata<=SYS_RATES_GSC_INCREMENT_PER_RF_CLOCK;
     default:begin
      if(s_axi_araddr>=REG_EVENT_WORD_0&&s_axi_araddr<=REG_EVENT_WORD_15&&s_axi_araddr[1:0]==0&&event_latched)s_axi_rdata<=event_word;
      else s_axi_rresp<=2;
     end
    endcase
   end
  end
 end
endmodule
