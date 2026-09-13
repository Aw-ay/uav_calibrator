`timescale 1ns/1ps
module tb_tx_tail_status;
 reg clk_rf=0;always #4 clk_rf=~clk_rf;
 reg rst=1,mode_request=0,safe_boundary=1,rf_permit=1,hard_fault=0,single_antenna_ota=1,config_commit=0;
 reg [2:0] requested_mode=0;reg [7:0] route_select=8'h10,route_enable=8'h11,cal_valid=8'hff;
 reg [127:0] dc_i=0,dc_q=0;reg [143:0] gain_i=0,gain_q=0;
 reg [31:0] config_id=7;
 reg [63:0] live_data=0,drfm_data=0,dds_data={16'd400,16'd300,16'd200,16'd100},awg_data=0;
 reg live_valid=0,drfm_valid=0,dds_valid=0,awg_valid=0;
 wire [2:0] active_mode;wire mode_accepted,mode_rejected,config_accepted,config_rejected;
 wire pipeline_ready;
 wire [31:0] active_config_id;wire [127:0] calibrated_i,calibrated_q;
 wire [7:0] calibrated_valid,calibration_saturated,tx_saturated,native_dac_valid;
 wire [1023:0] native_dac_data;
 wire tail_empty;
 tx_processing_chain dut(.*);
 task tick;begin @(posedge clk_rf);#1;@(negedge clk_rf);end endtask
 task drain(input bit require_energy);
  integer age;bit energy;begin age=0;energy=0;
   while(!tail_empty)begin
    tick();age++;if(native_dac_data!=0)energy=1;
    if(age>65)$fatal(1,"tail failed to empty");
   end
   if(native_dac_data!==0||native_dac_valid!==255)$fatal(1,"nonzero at first empty edge");
   if(age<58)$fatal(1,"tail closed early age=%0d",age);
   if(require_energy&&!energy)$fatal(1,"impulse never traversed FIR");
   repeat(20)begin tick();if(!tail_empty||native_dac_data!=0||native_dac_valid!=255)$fatal(1,"data after empty or invalid DAC stream");end
  end
 endtask
 task beat(input bit zero_data);begin
  @(negedge clk_rf);dds_data=zero_data?0:{16'd5000,16'd9000,16'd7000,16'd11000};dds_valid=1;
  #1;if(tail_empty)$fatal(1,"pending router input falsely empty");tick();dds_valid=0;
  #1;if(tail_empty)$fatal(1,"routed beat falsely empty");
 end endtask
 initial begin
  for(integer c=0;c<8;c++)gain_i[c*18+:18]=65536;
  tick();if(tail_empty)$fatal(1,"reset is not completion");rst=0;
  config_commit=1;tick();config_commit=0;requested_mode=3;mode_request=1;tick();mode_request=0;
  repeat(5)tick();if(!tail_empty)$fatal(1,"idle with no source samples");
  beat(0);drain(1);
  // A valid zero-valued beat still has a digital lifetime.
  beat(1);drain(0);
  // New samples extend the lifetime, including a gap shorter than FIR memory.
  beat(0);repeat(20)begin tick();if(tail_empty)$fatal(1,"gap early empty");end
  beat(0);drain(1);
  // Mute suppresses output immediately but does not flush stored history.
  beat(0);hard_fault=1;#1;if(tail_empty||native_dac_data!=0)$fatal(1,"mute incorrectly flushes history");
  drain(0);hard_fault=0;repeat(5)tick();
  beat(0);rst=1;tick();if(tail_empty)$fatal(1,"reset completion flag");rst=0;tick();
  if(!tail_empty||native_dac_data!=0)$fatal(1,"reset did not clear history");
  $display("PASS TX tail status real FIR impulse zero-beat retrigger gap mute reset continuous DAC valid");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
