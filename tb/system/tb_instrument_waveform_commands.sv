`timescale 1ns/1ps
module tb_instrument_waveform_commands;
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
 calibrator_instrument_core #(.PRE_SAMPLES(3),.FIFO_ADDR_W(2),.AWG_DEPTH(2048)) dut(.*);
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

 integer expected_events=0;reg [31:0] expected_event_seq[0:15];reg [31:0] expected_event_source[0:15];reg [63:0] event_token;
 reg [8191:0] payload=0,saved_config=0;integer sequence_id=0;
 task command(input [15:0] op,words,input [7:0] expected);reg [31:0] crc;integer polls;begin
  sequence_id=sequence_id+1;
  if(expected==0&&(op==CMD_DDS||op==CMD_AWG_PLAY))begin
   expected_event_seq[expected_events]=sequence_id;expected_event_source[expected_events]=(op==CMD_DDS)?1:2;expected_events=expected_events+1;
  end
  $display("COMMAND %0d time=%0t",op,$time);
  write_word(GW_STATUS,2,0);
  for(integer w=0;w<words;w=w+1)write_word(GW_PAYLOAD+4*w,payload[w*32+:32],0);
  write_word(GW_OP_LENGTH,{words,op},0);write_word(GW_SEQUENCE,sequence_id,0);
  crc=crc_word(crc_word(32'hffffffff,{words,op}),sequence_id);
  for(integer w=0;w<words;w=w+1)crc=crc_word(crc,payload[w*32+:32]);
  write_word(GW_CRC32C,~crc,0);write_word(GW_SUBMIT,1,0);
  polls=0;read_word(GW_STATUS);while(value[0]||!value[1])begin
   polls=polls+1;if(polls==150)$fatal(1,"command stuck op=%0d AWGstate=%0d mode=%0d",op,dut.dataplane.transmit.generated.awg.state,dut.d_t_active_mode);read_word(GW_STATUS);end
  if(value[15:8]!==expected)$fatal(1,"op %0d result %0d expected %0d",op,value[15:8],expected);
  read_word(GW_DONE_SEQUENCE);if(value!=sequence_id)$fatal(1,"completion sequence");
 end endtask
 task adc_level(input integer level);begin
  @(negedge rf_clk);for(integer c=0;c<8;c=c+1)for(integer s=0;s<4;s=s+1)begin
   native_adc_data[c*128+s*16+:16]=level;
   native_adc_data[c*128+64+s*16+:16]=0;
  end
 end endtask

 string root;reg [1023:0] headers[0:2],q;
 integer dn=0,an=0,done_dds=0,done_awg=0;reg check_dds=0,check_awg=0,saw_dac=0,check_replacement=0;
 reg [63:0] dstart,afirst;reg [31:0] accum;
 function automatic [63:0] aword(input integer n);begin aword={16'd700+n[15:0],16'd500+n[15:0],16'd300+n[15:0],16'd100+n[15:0]};end endfunction
 function automatic [63:0] dword(input integer n);reg [31:0] z;begin
  case(n%4)0:z=32'h00007fff;1:z=32'h7fff0000;2:z=32'h80010000;3:z=32'h00008001;endcase dword={z,z};end endfunction
 task awg(input [1:0] op,input [31:0] len,crc,input [63:0] data,input [7:0] code);begin
  payload=0;payload[1:0]=op;payload[63:32]=len;payload[95:64]=crc;payload[159:96]=data;
  command(CMD_AWG_LOAD,5,code);
 end endtask
 task dds(input [63:0] start,input [31:0] width,pri,count,input [7:0] code);begin
  payload=0;payload[63:0]=start;payload[95:64]=width;payload[127:96]=pri;payload[159:128]=count;
  payload[207:160]=48'h400000000000;payload[255:208]=48'h400000000000;payload[256]=1;
  command(CMD_DDS,9,code);
 end endtask
 always @(negedge rf_clk)if(binding_valid)begin pa_on_fb=pa_enable_req;tr_tx_fb=tr_tx_req;rx_protected_fb=rx_protect_req;end
 always @(posedge rf_clk)begin #1;
  if(rst_n)begin
   if(native_dac_valid!==255)$fatal(1,"DAC TVALID must remain continuous");
   for(integer lane=1;lane<8;lane=lane+1)if(native_dac_data[lane*128+:128]!==native_dac_data[127:0])$fatal(1,"identical H routes differ at DAC lane %0d",lane);
   if(!binding_valid&&(native_dac_data!==0||native_dac_valid!==255))$fatal(1,"UNBOUND zero code / continuous TVALID");
   if(native_dac_data!=0)saw_dac=1;
   if(dut.d_t_dds_done)done_dds=done_dds+1;
   if(dut.d_t_awg_done)done_awg=done_awg+1;
   if(check_dds&&dut.dataplane.transmit.dds_valid)begin
    if(dut.dataplane.transmit.dds_data!==dword(dn)||dut.dataplane.transmit.generated.dds_sample_gsc!==dstart+(dn/4)*24+(dn%4)*4)$fatal(1,"DDS actual samples/GSC index=%0d",dn);
    dn=dn+1;
   end
   if(check_replacement&&dut.dataplane.transmit.awg_valid)begin
    if(dut.dataplane.transmit.awg_data!==64'd123||!dut.dataplane.transmit.generated.awg_last)$fatal(1,"replacement table data/LAST");an=an+1;
   end
   if(check_awg&&dut.dataplane.transmit.awg_valid)begin
    if(an==0)afirst=dut.dataplane.transmit.generated.awg_sample_gsc;
    if(dut.dataplane.transmit.awg_data!==aword(an)||dut.dataplane.transmit.generated.awg_sample_gsc!==afirst+4*an||dut.dataplane.transmit.generated.awg_last!==(an==15))$fatal(1,"AWG actual samples/GSC/LAST index=%0d",an);
    an=an+1;
   end
  end
 end
 initial begin
  if(!$value$plusargs("ROOT=%s",root))$fatal(1,"ROOT required");
  $readmemh({root,"/headers.hex"},headers);
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
  command(18,0,0);read_word(GW_RESULT);if(value!==0)$fatal(1,"empty source events");
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
  saved_config=payload;command(CMD_CONFIG,CONFIG_WORDS,0);write_word(GW_IRQ_ENABLE,4,0);
  repeat(100)@(negedge rf_clk);command(CMD_TX_PROFILE,0,0);
  // BEGIN/WRITE may run while muted. COMMIT is acknowledged only in MUTE.
  awg(1,0,0,1,4);awg(0,0,0,0,4);awg(3,0,0,0,4);
  command(CMD_AWG_PLAY,0,4);dds(gsc+6000,4,6,2,4);
  accum=32'hffffffff;for(integer n=0;n<16;n=n+1)begin accum=crc_word(accum,aword(n));accum=crc_word(accum,aword(n)>>32);end
  awg(0,16,~accum,0,0);for(integer n=0;n<16;n=n+1)awg(1,0,0,aword(n),0);awg(2,0,0,0,0);
  read_word(GW_RESULT);if(value[3:0]!=10)$fatal(1,"committed AWG response flags");
  binding_valid=1;timing_valid=1;payload=1;command(CMD_RF_REQUEST,1,0);payload=3;command(CMD_RF_REQUEST,1,0);wait(dut.d_t_rf_permit);
  payload=4;command(CMD_MODE,1,0);check_awg=1;an=0;saw_dac=0;command(CMD_AWG_PLAY,0,0);
  repeat(100)@(negedge rf_clk);if(an!=16||!saw_dac||done_awg!=1)$fatal(1,"AWG real output/drain");check_awg=0;
  // CRC failure never replaces the active bank.
  awg(0,1,0,0,0);awg(1,0,0,64'd123,4);awg(2,0,0,0,4);
  check_awg=1;an=0;command(CMD_AWG_PLAY,0,0);repeat(100)@(negedge rf_clk);if(an!=16)$fatal(1,"bad CRC damaged active bank");check_awg=0;
  // A loaded replacement must not hang the single-inflight gateway in AWG mode.
  accum=crc_word(crc_word(32'hffffffff,32'd123),0);
  awg(0,1,~accum,0,0);awg(1,0,0,64'd123,0);awg(2,0,0,0,3);
  command(CMD_STOP,0,0);repeat(100)@(negedge rf_clk);if(native_dac_data!==0)$fatal(1,"STOP AWG zero");if(rf_fault)$fatal(1,"normal STOP falsely latched RF feedback fault");
  awg(2,0,0,0,0);read_word(GW_RESULT);if(value[3:0]!=10)$fatal(1,"replacement commit");
  payload=1;command(CMD_RF_REQUEST,1,0);payload=3;command(CMD_RF_REQUEST,1,0);wait(dut.d_t_rf_permit);
  payload=4;command(CMD_MODE,1,0);an=0;check_replacement=1;command(CMD_AWG_PLAY,0,0);
  repeat(100)@(negedge rf_clk);check_replacement=0;if(an!=1)$fatal(1,"replacement table length");
  payload=0;command(CMD_MODE,1,0);repeat(100)@(negedge rf_clk);
  payload=3;command(CMD_MODE,1,0);command(CMD_AWG_PLAY,0,4);
  dds(gsc+6001,4,6,2,4);dds(gsc+6000,0,6,2,4);dds(gsc+6000,7,6,2,4);dds(gsc-4,4,6,2,4);
  dstart=gsc+6000;dn=0;check_dds=1;saw_dac=0;dds(dstart,4,6,2,0);
  dds(gsc+6000,4,6,2,4);
  wait(done_dds==1);repeat(100)@(negedge rf_clk);if(dn!=8||!saw_dac)$fatal(1,"DDS source/output count %0d",dn);check_dds=0;
  // STOP cancels a scheduled train; it cannot reappear after re-arm.
  dds(gsc+12000,16,16,3,0);command(CMD_STOP,0,0);
  repeat(100)@(negedge rf_clk);if(dut.d_t_dds_busy||native_dac_data!==0)$fatal(1,"DDS STOP cancelled train");
  // Exercise STOP during actual source output, then loss of binding during TX.
  payload=1;command(CMD_RF_REQUEST,1,0);payload=3;command(CMD_RF_REQUEST,1,0);wait(dut.d_t_rf_permit);
  payload=3;command(CMD_MODE,1,0);dds(gsc+2000,3000,3000,1,0);
  wait(dut.dataplane.transmit.dds_valid);command(CMD_STOP,0,0);
  repeat(100)@(negedge rf_clk);if(rf_fault||dut.d_t_dds_busy||native_dac_data!==0)$fatal(1,"active DDS STOP/drain");
  payload=1;command(CMD_RF_REQUEST,1,0);payload=3;command(CMD_RF_REQUEST,1,0);wait(dut.d_t_rf_permit);
  payload=3;command(CMD_MODE,1,0);dds(gsc+2000,3000,3000,1,0);
  wait(native_dac_data!=0);@(negedge rf_clk);binding_valid=0;#1;if(native_dac_data!==0)$fatal(1,"active binding loss immediate zero");
  repeat(100)@(negedge rf_clk);if(dut.d_t_dds_busy)$fatal(1,"binding loss source drain");
  payload=3;command(CMD_RF_REQUEST,1,5);dds(gsc+6000,4,6,2,4);
  command(CMD_RESET,0,0);
  if(expected_events!=7||!irq)$fatal(1,"source event IRQ or expected count");
  for(integer e=0;e<7;e=e+1)begin
   command(18,0,0);read_word(GW_RESULT_LENGTH);if(value!==14)$fatal(1,"source PEEK length");
   read_word(GW_RESULT);if(value!==7-e)$fatal(1,"source event count");
   read_word(GW_RESULT+4);if(value!==0)$fatal(1,"source event drops");
   read_word(GW_RESULT+8);event_token[31:0]=value;read_word(GW_RESULT+12);event_token[63:32]=value;
   read_word(GW_RESULT+16);if(value!==32'h00020001)$fatal(1,"source event tag");
   read_word(GW_RESULT+20);if(value!==expected_event_source[e])$fatal(1,"source kind");
   read_word(GW_RESULT+24);if(value!==((e<4)?0:((e==6)?2:1)))$fatal(1,"source reason e=%0d got=%0d",e,value);
   read_word(GW_RESULT+28);if(value!==expected_event_seq[e])$fatal(1,"source command identity");
   read_word(GW_RESULT+32);if(value!==7)$fatal(1,"source config identity");
   read_word(GW_RESULT+36);if(value!==1)$fatal(1,"source timestamps validity");
   payload=0;payload[63:0]=event_token+1;command(19,2,4);
   command(18,0,0);read_word(GW_RESULT+8);if(value!==event_token[31:0])$fatal(1,"wrong token changed event");
   payload=0;payload[63:0]=event_token;command(19,2,0);
  end
  repeat(6)@(negedge ctrl_clk);if(irq!==0)$fatal(1,"source IRQ after drain");
  command(18,0,0);read_word(GW_RESULT);if(value!==0)$fatal(1,"source queue empty");
  $display("PASS SOURCE_EVENTS actual waveform identity completion cancellation IRQ");
  $display("PASS instrument waveform commands DDS exact chirp/GSC AWG CRC lifecycle STOP UNBOUND DAC");$finish;
 end
 initial begin #160000;$fatal(1,"waveform timeout");end
endmodule
