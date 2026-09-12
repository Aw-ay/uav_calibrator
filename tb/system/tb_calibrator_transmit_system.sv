`timescale 1ns/1ps
module tb_calibrator_transmit_system;
reg clk_rf=0,clk_ctrl=0;always #4 clk_rf=~clk_rf;always #5 clk_ctrl=~clk_ctrl;
reg rst_n=0,binding_valid=0,timing_valid=1,arm=0,tx_request=0,hard_fault=0,pll_locked=1,heartbeat=1,clear_fault=0;
reg pa_on_fb=0,tr_tx_fb=0,rx_protected_fb=1;
wire pa_enable_req,tr_tx_req,rx_protect_req,rf_dac_mute,rf_fault,unbound,rf_permit;wire [2:0] rf_state;
// Logical test fixture only: normalized simulated feedback follows requests.
always @(negedge clk_rf)begin pa_on_fb=pa_enable_req;tr_tx_fb=tr_tx_req;rx_protected_fb=rx_protect_req;end
reg [31:0] protect_cycles=1,switch_cycles=1,pa_cycles=1,recovery_cycles=1,transition_timeout_cycles=100,watchdog_cycles=1000;
reg stop_request=0,safe_boundary=1,mode_request=0,config_commit=0,single_antenna_ota=1;reg [2:0] requested_mode=0;
reg [7:0] route_select=8'hf0,route_enable=255,cal_valid=255;reg [127:0] dc_i=0,dc_q=0;reg [143:0] gain_i=0,gain_q=0;reg [31:0] config_id=1;
reg [63:0] live_data=0,drfm_data=0;reg live_valid=0,drfm_valid=0;
reg [63:0] gsc=0;always @(posedge clk_rf)if(rst_n)gsc<=gsc+4;else gsc<=0;
reg dds_cmd_valid=0;reg [63:0] dds_start_gsc=0;reg [31:0] dds_pw_samples=128,dds_pri_samples=128,dds_pulse_count=1;
reg [47:0] dds_initial_pinc=48'h400000000000,dds_chirp_step=0;reg dds_reset_each_pulse=1;
wire dds_accepted,dds_rejected,dds_busy,dds_done;
reg awg_ctrl_valid=0;reg [1:0] awg_ctrl_op=0;reg [31:0] awg_ctrl_length=128,awg_ctrl_crc32c=0;reg [63:0] awg_ctrl_data=0;wire awg_ctrl_ready,awg_ctrl_done,awg_ctrl_error,awg_ctrl_loaded,awg_ctrl_active_valid;wire [1:0] awg_ctrl_done_op;
reg awg_play=0;wire awg_play_accepted,awg_play_rejected,awg_busy,awg_done,awg_done_cancelled;
wire [2:0] active_mode;wire mode_accepted,mode_rejected,config_accepted,config_rejected,pipeline_ready,start_ready,sources_drained;wire [31:0] active_config_id;
wire [127:0] calibrated_i,calibrated_q;wire [7:0] calibrated_valid,calibration_saturated,tx_saturated,native_dac_valid;wire [1023:0] native_dac_data;
calibrator_transmit_system #(.AWG_DEPTH(128)) dut(.*);
task tick;begin @(posedge clk_rf);#1;end endtask
task mode(input [2:0] m);begin @(negedge clk_rf);requested_mode=m;mode_request=1;tick;@(negedge clk_rf);mode_request=0;end endtask
task prepare;integer t;begin
 @(negedge clk_rf);arm=1;tx_request=0;clear_fault=0;t=0;
 while(rf_state!=1&&t<100)begin tick;t=t+1;end;if(rf_state!=1)$fatal(1,"RX prepare");
 @(negedge clk_rf);tx_request=1;t=0;while(!rf_permit&&t<100)begin tick;t=t+1;end;if(!rf_permit)$fatal(1,"TX interlock prepare");
 t=0;while(!pipeline_ready&&t<100)begin tick;t=t+1;end;if(!pipeline_ready)$fatal(1,"TX pipe recovery");
end endtask
task wait_start;integer t;begin t=0;while(!start_ready&&t<100)begin tick;t=t+1;end;if(!start_ready)$fatal(1,"start readiness");end endtask
function [31:0] cw(input [31:0] c,input [63:0] w);reg [31:0] x;integer k;begin x=c;for(k=0;k<64;k=k+1)if(x[0]^w[k])x=(x>>1)^32'h82f63b78;else x=x>>1;cw=x;end endfunction
task send(input [1:0] op,input [63:0] w);integer t;begin
 @(negedge clk_ctrl);while(!awg_ctrl_ready)@(negedge clk_ctrl);awg_ctrl_op=op;awg_ctrl_data=w;awg_ctrl_valid=1;
 @(posedge clk_ctrl);#1;@(negedge clk_ctrl);awg_ctrl_valid=0;t=0;
 while(!awg_ctrl_done&&t<500)begin @(posedge clk_ctrl);#1;t=t+1;end
 if(!awg_ctrl_done||awg_ctrl_error)$fatal(1,"AWG load response");
end endtask
integer count_dds=0,c,i,t,lane,hi,vi;reg check_dds=0,check_awg=0;reg [7:0] seen_dac=0;reg [31:0] crc;reg signed [15:0] expected_i,expected_q;
always @(posedge clk_rf)begin #1;
 if(check_dds&&calibrated_valid==255)begin
  case(count_dds%4)0:begin expected_i=32767;expected_q=0;end 1:begin expected_i=0;expected_q=32767;end 2:begin expected_i=-32767;expected_q=0;end 3:begin expected_i=0;expected_q=-32767;end endcase
  for(c=0;c<8;c=c+1)if($signed(calibrated_i[c*16+:16])!=expected_i||$signed(calibrated_q[c*16+:16])!=expected_q)$fatal(1,"DDS sample lost or changed %0d lane%0d",count_dds,c);
  count_dds=count_dds+1;
 end
 if(check_awg&&calibrated_valid==255)for(c=0;c<8;c=c+1)if(calibrated_i[c*16+:16]!=(c<4?1000:2000)||calibrated_q[c*16+:16]!=0)$fatal(1,"AWG route/cal source mismatch");
 if(check_dds||check_awg)for(c=0;c<8;c=c+1)if(native_dac_data[c*128+:128]!=0)seen_dac[c]=1;
 if(!binding_valid&&native_dac_data!=0)$fatal(1,"UNBOUND nonzero output");
end
initial begin
 for(i=0;i<8;i=i+1)gain_i[i*18+:18]=65536;
 repeat(3)tick;rst_n=1;repeat(5)tick;
 @(negedge clk_rf);config_commit=1;tick;@(negedge clk_rf);config_commit=0;repeat(2)tick;if(!active_config_id)$fatal(1,"initial TX config");
 arm=1;tx_request=1;mode(3);if(!mode_rejected||rf_permit||start_ready||pa_enable_req)$fatal(1,"UNBOUND transmit admission");
 @(negedge clk_rf);dds_cmd_valid=1;dds_start_gsc=gsc+16;tick;if(!dds_rejected||dds_busy)$fatal(1,"UNBOUND DDS started");@(negedge clk_rf);dds_cmd_valid=0;arm=0;tx_request=0;binding_valid=1;
 // A command during TURNAROUND is rejected, preventing a missing pulse prefix.
 @(negedge clk_rf);arm=1;repeat(3)tick;@(negedge clk_rf);tx_request=1;tick;
 @(negedge clk_rf);dds_cmd_valid=1;dds_start_gsc=gsc+16;tick;if(!dds_rejected||dds_busy||start_ready)$fatal(1,"TURNAROUND premature DDS");@(negedge clk_rf);dds_cmd_valid=0;
 t=0;while(!pipeline_ready&&t<100)begin tick;t=t+1;end;mode(3);if(!mode_accepted)$fatal(1,"DDS mode");wait_start;
 @(negedge clk_rf);dds_start_gsc=gsc+16;dds_cmd_valid=1;check_dds=1;tick;if(!dds_accepted)$fatal(1,"DDS accepted after permit");@(negedge clk_rf);dds_cmd_valid=0;
 repeat(160)tick;if(count_dds!=128||seen_dac!=255)$fatal(1,"DDS full pulse / eight DAC count%0d mask%h",count_dds,seen_dac);check_dds=0;
 mode(0);#1;if(native_dac_data!=0)$fatal(1,"MUTE zero");mode(4);if(!mode_rejected)$fatal(1,"restart before TX drain");
 repeat(65)tick;mode(4);repeat(4)tick;if(start_ready)$fatal(1,"AWG ready without active table");
 @(negedge clk_rf);awg_play=1;tick;if(!awg_play_rejected)$fatal(1,"empty AWG play admitted");@(negedge clk_rf);awg_play=0;mode(0);repeat(3)tick;
 crc=32'hffffffff;for(i=0;i<128;i=i+1)crc=cw(crc,{16'd0,16'd2000,16'd0,16'd1000});awg_ctrl_crc32c=~crc;
 send(0,0);for(i=0;i<128;i=i+1)send(1,{16'd0,16'd2000,16'd0,16'd1000});send(2,0);
 mode(4);if(!mode_accepted)$fatal(1,"AWG mode");wait_start;@(negedge clk_rf);awg_play=1;check_awg=1;seen_dac=0;tick;if(!awg_play_accepted)$fatal(1,"AWG start");@(negedge clk_rf);awg_play=0;
 repeat(100)tick;if(seen_dac!=255)$fatal(1,"AWG eight DAC output");
 // Steady-state constant AWG traverses the actual interpolation chain.
 for(lane=0;lane<4;lane=lane+1)begin
  hi=$signed(native_dac_data[lane*32+:16]);vi=$signed(native_dac_data[4*128+lane*32+:16]);
  if(hi<900||hi>1100||vi<2*hi-4||vi>2*hi+4||native_dac_data[lane*32+16+:16]!=0||native_dac_data[4*128+lane*32+16+:16]!=0)$fatal(1,"AWG DAC numeric/reference routing %0d %0d",hi,vi);
 end
 for(c=1;c<4;c=c+1)if(native_dac_data[c*128+:128]!=native_dac_data[0+:128]||native_dac_data[(c+4)*128+:128]!=native_dac_data[4*128+:128])$fatal(1,"eight DAC fanout mismatch");
 @(negedge clk_rf);hard_fault=1;#1;if(native_dac_data!=0||native_dac_valid!=255||pa_enable_req)$fatal(1,"fault immediate zero");tick;check_awg=0;
 @(negedge clk_rf);hard_fault=0;arm=0;tx_request=0;clear_fault=1;tick;@(negedge clk_rf);clear_fault=0;
 prepare;mode(3);if(!mode_accepted)$fatal(1,"fault reprepare mode");wait_start;
 repeat(4)tick;if(native_dac_data!=0)$fatal(1,"old AWG tail resumed after reprepare");
 count_dds=0;seen_dac=0;dds_pw_samples=8;dds_pri_samples=8;
 @(negedge clk_rf);dds_start_gsc=gsc+16;dds_cmd_valid=1;check_dds=1;tick;if(!dds_accepted)$fatal(1,"fresh DDS after fault");@(negedge clk_rf);dds_cmd_valid=0;repeat(80)tick;
 if(count_dds!=8||seen_dac!=255)$fatal(1,"fresh postfault waveform");check_dds=0;
 @(negedge clk_rf);binding_valid=0;#1;if(native_dac_data!=0||pa_enable_req||!unbound)$fatal(1,"binding loss zero");
 $display("PASS calibrator transmit UNBOUND interlock DDS AWG eightDAC fault reprepare");$finish;
end
initial begin #1000000;$fatal(1,"system watchdog");end
endmodule
