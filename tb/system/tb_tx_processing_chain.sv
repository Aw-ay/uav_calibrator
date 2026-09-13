`timescale 1ns/1ps
module tb_tx_processing_chain;
 reg clk_rf=0;always #4 clk_rf=~clk_rf;
 reg rst=1,mode_request=0,safe_boundary=1,rf_permit=1,hard_fault=0,single_antenna_ota=1,config_commit=0;
 reg [2:0] requested_mode=0;reg [7:0] route_select=8'h10,route_enable=8'h11,cal_valid=8'hff;
 reg [127:0] dc_i=0,dc_q=0;reg [143:0] gain_i=0,gain_q=0;
 reg [31:0] config_id=7;
 reg [63:0] live_data=0,drfm_data=0,dds_data={16'd400,16'd300,16'd200,16'd100},awg_data=0;
 reg live_valid=1,drfm_valid=1,dds_valid=1,awg_valid=1;
 wire [2:0] active_mode;wire mode_accepted,mode_rejected,config_accepted,config_rejected;
 wire pipeline_ready,tail_empty;
 wire [31:0] active_config_id;wire [127:0] calibrated_i,calibrated_q;
 wire [7:0] calibrated_valid,calibration_saturated,tx_saturated,native_dac_valid;
 wire [1023:0] native_dac_data;
 tx_processing_chain dut(.*);
 task tick;begin @(posedge clk_rf);#1;@(negedge clk_rf);end endtask
 initial begin
  for(integer c=0;c<8;c=c+1)begin gain_i[c*18+:18]=65536;dc_i[c*16+:16]=55;dc_q[c*16+:16]=66;end
  dc_i[0+:16]=0;dc_q[0+:16]=0;dc_i[64+:16]=0;dc_q[64+:16]=0;gain_i[72+:18]=32768;
  tick();rst=0;config_commit=1;tick();config_commit=0;if(!config_accepted)$fatal(1,"mute config");
  safe_boundary=0;requested_mode=3;mode_request=1;tick();mode_request=0;
  requested_mode=0;mode_request=1;tick();mode_request=0;
  if(active_mode!=0||!mode_accepted||mode_rejected)$fatal(1,"MUTE cancels pending DDS start");
  safe_boundary=1;repeat(80)begin tick();if(active_mode!=0||native_dac_data!=0)$fatal(1,"cancelled DDS must never escape MUTE");end
  requested_mode=3;mode_request=1;tick();mode_request=0;
  repeat(8)tick();
  if(active_mode!=3||calibrated_valid!=8'h11||calibrated_i[0+:16]!=100||calibrated_q[0+:16]!=200||calibrated_i[64+:16]!=150||calibrated_q[64+:16]!=200)$fatal(1,"route and per DAC calibration");
  for(integer c=0;c<8;c=c+1)if(c!=0&&c!=4&&(calibrated_i[c*16+:16]!=0||calibrated_q[c*16+:16]!=0))$fatal(1,"disabled lane DC leak");
  gain_i=0;dc_i=0;dc_q=0;config_id=99;route_enable=255;config_commit=1;tick();config_commit=0;
  if(!config_rejected||active_config_id!=7)$fatal(1,"active update rejection");
  repeat(80)tick();if(calibrated_i[0+:16]!=100||native_dac_data==0)$fatal(1,"frozen coeff and real interpolation");
  hard_fault=1;#1;if(native_dac_data!=0||native_dac_valid!=255)$fatal(1,"immediate fault zero code valid");
  tick();hard_fault=0;rf_permit=0;#1;if(native_dac_data!=0)$fatal(1,"permit mute");
  requested_mode=0;mode_request=1;tick();mode_request=0;repeat(3)tick();
  if(active_mode!=0)$fatal(1,"mute switch");
  rf_permit=1;#1;if(native_dac_data!=0)$fatal(1,"MUTE overrides FIR tail");
  requested_mode=4;mode_request=1;tick();mode_request=0;
  if(!mode_rejected||active_mode!=0)$fatal(1,"restart must wait for previous FIR history");
  repeat(64)tick();
  config_commit=1;tick();config_commit=0;if(!config_accepted||active_config_id!=99)$fatal(1,"safe atomic update");
  requested_mode=4;mode_request=1;tick();mode_request=0;
  repeat(70)begin tick();if(native_dac_data!=0)$fatal(1,"zero AWG has no old DDS tail");end
  $display("PASS TX processing chain common calibration route coefficient pin FIR fault zero-code");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
