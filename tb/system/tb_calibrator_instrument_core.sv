`timescale 1ns/1ps
module tb_calibrator_instrument_core;
 import command_gateway_pkg::*;
 import instrument_control_pkg::*;
 import replay_control_layout_pkg::*;
 reg ctrl_clk,rf_clk,mem_clk,rst_n;
 reg [31:0] s_axi_awaddr;reg s_axi_awvalid;wire s_axi_awready;
 reg [31:0] s_axi_wdata;reg [3:0] s_axi_wstrb;reg s_axi_wvalid;wire s_axi_wready;
 wire [1:0] s_axi_bresp;wire s_axi_bvalid;reg s_axi_bready;
 reg [31:0] s_axi_araddr;reg s_axi_arvalid;wire s_axi_arready;
 wire [31:0] s_axi_rdata;wire [1:0] s_axi_rresp;wire s_axi_rvalid;reg s_axi_rready;wire irq;
 reg [1023:0] native_adc_data;reg [15:0] native_adc_valid;wire [15:0] native_adc_ready;
 wire [1023:0] native_dac_data;wire [7:0] native_dac_valid;
 wire [127:0] m_axis_tdata;wire [15:0] m_axis_tkeep;wire m_axis_tvalid,m_axis_tlast;reg m_axis_tready;
 reg common_clock_good,time_valid,mapping_valid;reg [7:0] mts_locked;reg [23:0] logical_to_physical;
 reg [7:0] hard_overrange_event,hard_overrange_known;
 reg [31:0] source_epoch;reg source_stable,profiles_authorized,guard_clear,planned_slot_clear,latency_validated,live_range_authorized;
 reg [63:0] downstream_latency_ticks;reg phase_valid;reg signed [17:0] phase_i,phase_q;
 reg binding_valid,timing_valid,hard_fault,pll_locked,heartbeat,pa_on_fb,tr_tx_fb,rx_protected_fb,single_antenna_ota;
 reg [31:0] protect_cycles,switch_cycles,pa_cycles,recovery_cycles,transition_timeout_cycles,watchdog_cycles;
 wire pa_enable_req,tr_tx_req,rx_protect_req,rf_dac_mute,rf_fault,unbound;
 wire run_enable,config_loaded;wire [63:0] gsc;
 calibrator_instrument_core #(.PRE_SAMPLES(3),.FIFO_ADDR_W(2),.AWG_DEPTH(16)) dut(.*);
 initial begin ctrl_clk=0;forever #5 ctrl_clk=~ctrl_clk;end
 initial begin rf_clk=0;#0.7;forever #4 rf_clk=~rf_clk;end
 initial begin mem_clk=0;#0.3;forever #2.5 mem_clk=~mem_clk;end
 task write_word(input [31:0] a,v,input [1:0] expected);begin
  @(negedge ctrl_clk);s_axi_awaddr=a;s_axi_awvalid=1;
  do begin @(posedge ctrl_clk);end while(!s_axi_awready);
  @(negedge ctrl_clk);s_axi_awvalid=0;repeat(2)@(negedge ctrl_clk);
  s_axi_wdata=v;s_axi_wvalid=1;do begin @(posedge ctrl_clk);end while(!s_axi_wready);
  @(negedge ctrl_clk);s_axi_wvalid=0;wait(s_axi_bvalid);if(s_axi_bresp!==expected)$fatal(1,"write response %h",a);@(negedge ctrl_clk);
 end endtask
 reg [31:0] value;
 task read_word(input [31:0] a);begin
  @(negedge ctrl_clk);s_axi_araddr=a;s_axi_arvalid=1;do begin @(posedge ctrl_clk);end while(!s_axi_arready);
  @(negedge ctrl_clk);s_axi_arvalid=0;wait(s_axi_rvalid);if(s_axi_rresp!=0)$fatal(1,"read response");value=s_axi_rdata;@(negedge ctrl_clk);
 end endtask
 function automatic [31:0] crc_word(input [31:0] initial_crc,v);reg [31:0] c;begin c=initial_crc;for(integer k=0;k<32;k=k+1)c=(c>>1)^((c[0]^v[k])?32'h82f63b78:0);crc_word=c;end endfunction

 reg [8191:0] payload=0,saved_config=0;integer sequence_id=0;
 task command(input [15:0] op,words,input [7:0] expected);reg [31:0] crc;begin
  sequence_id=sequence_id+1;$display("COMMAND %0d time=%0t",op,$time);
  write_word(GW_STATUS,2,0);
  for(integer w=0;w<words;w=w+1)write_word(GW_PAYLOAD+4*w,payload[w*32+:32],0);
  write_word(GW_OP_LENGTH,{words,op},0);write_word(GW_SEQUENCE,sequence_id,0);
  crc=crc_word(crc_word(32'hffffffff,{words,op}),sequence_id);
  for(integer w=0;w<words;w=w+1)crc=crc_word(crc,payload[w*32+:32]);
  write_word(GW_CRC32C,~crc,0);write_word(GW_SUBMIT,1,0);
  read_word(GW_STATUS);while(value[0]||!value[1])read_word(GW_STATUS);
  if(value[15:8]!==expected)$fatal(1,"op %0d result %0d expected %0d",op,value[15:8],expected);
  read_word(GW_DONE_SEQUENCE);if(value!=sequence_id)$fatal(1,"completion sequence");
 end endtask
 task adc_level(input integer level);begin
  @(negedge rf_clk);for(integer c=0;c<8;c=c+1)for(integer s=0;s<4;s=s+1)begin
   native_adc_data[c*128+s*16+:16]=level;
   native_adc_data[c*128+64+s*16+:16]=0;
  end
 end endtask
 integer bytes_seen=0,frames=0,onsets=0,ends=0,completions=0;
 integer frame_file,sample_file;string root;reg [3711:0] snapshot;integer pdw_file;reg [639:0] pdw_snapshot;reg [63:0] pdw_token;integer replay_samples=0;reg saw_dac=0;
 always @(posedge rf_clk)if(rst_n)begin
  if(dut.d_r_raw_valid)replay_samples=replay_samples+1;
  if(binding_valid&&native_dac_data!=0)saw_dac=1;
 end
 always @(negedge rf_clk)if(binding_valid)begin pa_on_fb=pa_enable_req;tr_tx_fb=tr_tx_req;rx_protected_fb=rx_protect_req;end
 always @(posedge mem_clk)if(rst_n&&m_axis_tvalid&&m_axis_tready)begin
  for(integer b=0;b<16;b=b+1)if(m_axis_tkeep[b])begin $fdisplay(frame_file,"%02x",m_axis_tdata[b*8+:8]);bytes_seen=bytes_seen+1;end
  if(m_axis_tlast)frames=frames+1;
 end
 always @(posedge rf_clk)if(rst_n)begin
  if(!binding_valid&&native_dac_data!==0)$fatal(1,"unbound DAC must remain zero");
  if(dut.sample_valid)$fdisplay(sample_file,"%0d %0d %016x",dut.sample_seq,dut.sample_gsc,dut.group_data[63:0]);
  if(dut.onset_valid)begin onsets=onsets+1;$display("ONSET %0d %0d",dut.onset_seq,dut.onset_gsc);end
  if(dut.eop_event_valid)begin ends=ends+1;$display("EOP %0d",dut.eop_event_stop);end
  if(dut.d_completion_valid)begin completions=completions+1;if(dut.d_completion_error)$fatal(1,"DMA completion error");end
  if(dut.d_producer_error_valid||dut.d_disposition_rejected)$fatal(1,"capture rejected reason %0d",dut.d_producer_error_reason);
 end
 reg [1023:0] headers[0:2];reg [1023:0] q;
 initial begin
  if(!$value$plusargs("ROOT=%s",root))$fatal(1,"ROOT required");
  $readmemh({root,"/headers.hex"},headers);
  frame_file=$fopen({root,"/instrument_frame.hex"},"w");sample_file=$fopen({root,"/instrument_samples.txt"},"w");
  rst_n=0;s_axi_awaddr=0;s_axi_wdata=0;s_axi_araddr=0;s_axi_wstrb=15;
  s_axi_awvalid=0;s_axi_wvalid=0;s_axi_bready=1;s_axi_arvalid=0;s_axi_rready=1;
  native_adc_data=0;native_adc_valid=65535;m_axis_tready=0;
  common_clock_good=1;time_valid=1;mapping_valid=1;mts_locked=255;logical_to_physical=24'hfa5681;
  hard_overrange_event=0;hard_overrange_known=255;source_epoch=13;source_stable=1;profiles_authorized=1;
  guard_clear=1;planned_slot_clear=1;latency_validated=1;live_range_authorized=1;downstream_latency_ticks=0;
  phase_valid=1;phase_i=65536;phase_q=0;binding_valid=0;timing_valid=0;hard_fault=0;pll_locked=1;heartbeat=1;
  pa_on_fb=0;tr_tx_fb=0;rx_protected_fb=0;single_antenna_ota=0;
  protect_cycles=1;switch_cycles=1;pa_cycles=1;recovery_cycles=1;transition_timeout_cycles=100;watchdog_cycles=1000;
  repeat(6)@(negedge ctrl_clk);rst_n=1;adc_level(10);
  command(CMD_STATUS,0,0);read_word(GW_RESULT_LENGTH);if(value!=116)$fatal(1,"snapshot length");
  command(CMD_ARM,0,3);
  q=0;for(integer c=0;c<6;c=c+1)q[c*32+:32]=65536;
  q[239:224]=6553;q[223:192]=65536;q[245:240]=6'b100100;
  q[251:246]=63;q[257:252]=63;q[263:258]=63;
  payload=0;payload[CFG_CONFIG_VERSION_BIT+:32]=7;payload[CFG_QUALIFICATION_BIT+:1024]=q;
  payload[CFG_METADATA_BIT+:1024]=headers[0];payload[CFG_WANT_REPLAY_BIT]=1;
  payload[CFG_ON_POWER_BIT+:33]=100000;payload[CFG_OFF_POWER_BIT+:33]=1000;
  payload[CFG_EOP_HOLD_BIT+:14]=2;payload[CFG_MAX_BODY_BIT+:14]=1000;payload[CFG_POST_SAMPLES_BIT+:16]=4;
  payload[CFG_NOISE_ENABLE_BIT]=1;payload[CFG_NOISE_SHIFT_BIT+:5]=4;payload[CFG_NOISE_MAX_AGE_BIT+:32]=10000;
  for(integer c=0;c<8;c=c+1)begin
   payload[CFG_NEAR_CLIP_THRESHOLD_BIT+c*17+:17]=30000;
   payload[CFG_T_GAIN_I_BIT+c*18+:18]=65536;payload[CFG_T_GAIN_Q_BIT+c*18+:18]=65536;
  end
  payload[CFG_THRESHOLD_VALIDATED_BIT+:8]=255;payload[CFG_R_CURRENT_FIR_ID_BIT+:32]=12;
  payload[CFG_R_SHADOW_CAL_VALID_BIT+:2]=3;payload[CFG_R_SHADOW_GAIN_BIT+:72]={4{18'd65536}};
  payload[CFG_R_SHADOW_MATRIX_BIT+:18]=65536;payload[CFG_R_SHADOW_MATRIX_BIT+108+:18]=65536;
  payload[CFG_R_SHADOW_FD_VERSION_BIT+:32]=32'h9d1dc12a;payload[CFG_R_SHADOW_RX_CAL_ID_BIT+:32]=101;payload[CFG_R_SHADOW_TARGET_MATRIX_ID_BIT+:32]=102;
  payload[CFG_R_SHADOW_DOPPLER_PHASE_ID_BIT+:32]=103;payload[CFG_T_ROUTE_ENABLE_BIT+:8]=255;
  payload[CFG_T_CAL_VALID_BIT+:8]=255;payload[CFG_T_CONFIG_ID_BIT+:32]=7;
  saved_config=payload;command(CMD_CONFIG,CONFIG_WORDS,0);
  repeat(100)@(negedge rf_clk);
  command(CMD_RX_PROFILE,0,4);command(CMD_TX_PROFILE,0,0);
  payload=3;command(CMD_RF_REQUEST,1,5);
  command(CMD_ARM,0,0);if(!run_enable)$fatal(1,"ARM did not reach producer");
  payload=saved_config;command(CMD_CONFIG,CONFIG_WORDS,3);
  repeat(100)@(negedge rf_clk);adc_level(1000);repeat(80)@(negedge rf_clk);adc_level(10);
  wait(dut.d_fifo_occupancy==4);repeat(100)@(negedge rf_clk);
  if(completions!=0)$fatal(1,"stalled RAW retired early");
  m_axis_tready=1;wait(frames==1&&completions==1);repeat(20)@(negedge rf_clk);
  if(onsets!=1||ends!=1||dut.d_replay_leased==0||dut.source_dropped!=0)$fatal(1,"production or lease");
  command(16,0,0);read_word(GW_RESULT_LENGTH);if(value!=20)$fatal(1,"PDW result length");
  pdw_file=$fopen({root,"/instrument_pdw.hex"},"w");
  for(integer w=0;w<20;w=w+1)begin read_word(GW_RESULT+4*w);pdw_snapshot[w*32+:32]=value;$fdisplay(pdw_file,"%08x",value);end
  $fclose(pdw_file);if(pdw_snapshot[31:0]!=1||pdw_snapshot[63:32]!=0)$fatal(1,"expected one PDW without drops");
  pdw_token=pdw_snapshot[127:64];payload=0;payload[63:0]=pdw_token+1;command(17,2,4);
  command(16,0,0);read_word(GW_RESULT+16);if(value!=32'h00010001)$fatal(1,"PDW peek changed after wrong token");
  command(16,0,0);read_word(GW_RESULT+8);if(value!=pdw_token[31:0])$fatal(1,"repeated PEEK changed token");
  command(CMD_STATUS,0,0);read_word(GW_RESULT+16);if(value!=7)$fatal(1,"snapshot config");
  for(integer w=0;w<116;w=w+1)begin read_word(GW_RESULT+4*w);snapshot[w*32+:32]=value;end
  if(snapshot[255:240]!=1)$fatal(1,"expected group 1 bank 0 lease");
  binding_valid=1;timing_valid=1;payload=1;command(CMD_RF_REQUEST,1,0);payload=3;command(CMD_RF_REQUEST,1,0);wait(dut.d_t_rf_permit);
  payload=2;command(CMD_MODE,1,0);command(CMD_RX_PROFILE,0,0);
  payload=0;payload[OWNER_EPOCH_BIT+:64]=snapshot[127:64];payload[GENERATION_BIT+:64]=snapshot[319:256];
  payload[PULSE_ID_BIT+:64]=snapshot[2367:2304];payload[START_SEQ_BIT+:64]=snapshot[1343:1280];
  payload[START_PTR_BIT+:32]=snapshot[1311:1280]&16383;payload[STREAM_GROUP_ID_BIT+:32]=1;
  payload[SAMPLE_COUNT_BIT+:32]={17'd0,snapshot[3342:3328]};payload[CONFIG_ID_BIT+:32]=7;
  payload[FIR_ID_BIT+:32]=12;payload[SOURCE_EPOCH_BIT+:32]=13;payload[SOURCE_ROLE_BIT+:32]=1;
  payload[TARGET_GSC_BIT+:64]=gsc+6000;payload[TASK_ID_BIT+:64]=77;payload[OUTPUT_DAC_MASK_BIT+:32]=255;
  payload[RX_CAL_ID_BIT+:32]=101;payload[TARGET_MATRIX_ID_BIT+:32]=102;payload[DOPPLER_PHASE_ID_BIT+:32]=103;
  command(CMD_REPLAY,48,0);wait(dut.d_r_dsp_done||dut.d_r_rejected_valid);
  if(dut.d_r_rejected_valid)$fatal(1,"PS replay rejection %0d",dut.d_r_reject_reason);
  repeat(100)@(negedge rf_clk);
  if(replay_samples!=snapshot[3342:3328]||!saw_dac||dut.d_replay_leased!=0)$fatal(1,"PS replay did not traverse actual TX");
  binding_valid=0;#1;if(native_dac_data!=0)$fatal(1,"binding loss zero code");
  command(CMD_STOP,0,0);if(run_enable)$fatal(1,"STOP not applied");
  command(CMD_RESET,0,0);if(dut.d_owner_epoch!=1||dut.d_replay_leased!=0)$fatal(1,"reset did not drain lease");
  command(16,0,0);read_word(GW_RESULT);if(value!=1)$fatal(1,"soft reset lost historical PDW");
  read_word(GW_RESULT+32);if(value!=0)$fatal(1,"historical PDW epoch rewritten by reset");
  payload=0;payload[63:0]=pdw_token;command(17,2,0);command(17,2,4);
  command(16,0,0);read_word(GW_RESULT);if(value!=0)$fatal(1,"PDW not popped");
  $fclose(frame_file);$fclose(sample_file);
  $display("PASS instrument core PS configuration ARM native ADC FIR detector capture RAW replay TX profiles UNBOUND STOP RESET bytes=%0d",bytes_seen);$finish;
 end
 initial begin #100000;$fatal(1,"timeout opcode=%0d wait=%b onsets=%0d ends=%0d frozen=%h error=%d",dut.action_opcode,dut.executor.waiting,onsets,ends,dut.d_frozen,dut.d_record_errors);end
endmodule
