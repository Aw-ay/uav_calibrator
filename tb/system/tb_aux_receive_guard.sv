`timescale 1ns/1ps
module tb_aux_receive_guard;
 reg clk_rf=0,rst=1,enable=1;always #4 clk_rf=~clk_rf;
 reg [1023:0] native_adc_data=0;reg [15:0] native_adc_valid=65535;wire [15:0] native_adc_ready;
 reg [63:0] native_seq=0,native_gsc=1000;reg common_clock_good=1,mapping_valid=1;reg [7:0] mts_locked=255;
 reg [23:0] logical_to_physical=0;reg [135:0] near_clip_threshold=0;
 reg [7:0] threshold_validated=255,hard_overrange_event=0,hard_overrange_known=255;
 wire sample_valid;wire [63:0] sample_seq,sample_gsc;wire [255:0] group_data;
 wire [7:0] logical_good,logical_saturated,physical_good,physical_saturated;
 calibrator_receive_frontend frontend(.*);
 reg binding_valid=1,timing_valid=1,safe_to_switch=1,commit=0,source_ack=0;
 reg [1:0] source_shadow=1,source_feedback=0,calibration_valid=3;
 reg [31:0] h_calibration_shadow=7,v_calibration_shadow=9,settling_cycles=0,flush_samples=58,switch_timeout_cycles=20;
 wire [1:0] source_request,source_active;wire busy,aux_valid,rejected,done,unbound;
 wire [31:0] source_epoch,drop_count,h_calibration_id,v_calibration_id;
 wire [7:0] source_role;wire [63:0] aux_data,aux_seq,aux_gsc;
 aux_receive_guard guard(.clk_rf(clk_rf),.rst_n(!rst),.binding_valid(binding_valid),.timing_valid(timing_valid),
  .safe_to_switch(safe_to_switch),.commit(commit),.source_shadow(source_shadow),.source_ack(source_ack),.source_feedback(source_feedback),
  .calibration_valid(calibration_valid),.h_calibration_shadow(h_calibration_shadow),.v_calibration_shadow(v_calibration_shadow),
  .settling_cycles(settling_cycles),.flush_samples(flush_samples),.switch_timeout_cycles(switch_timeout_cycles),
  .sample_valid(sample_valid),.sample_good(logical_good[3]&&logical_good[7]),.sample_data(group_data[192+:64]),
  .sample_seq(sample_seq),.sample_gsc(sample_gsc),.source_request(source_request),.source_active(source_active),
  .busy(busy),.aux_valid(aux_valid),.rejected(rejected),.done(done),.unbound(unbound),.source_epoch(source_epoch),.drop_count(drop_count),
  .source_role(source_role),.h_calibration_id(h_calibration_id),.v_calibration_id(v_calibration_id),.aux_data(aux_data),.aux_seq(aux_seq),.aux_gsc(aux_gsc));
 reg check_main=0;reg [63:0] previous_seq;integer last_dirty=0;
 task tick;begin @(posedge clk_rf);#1;
  if(check_main)begin
   if(!sample_valid||native_adc_ready!=65535||((logical_good&8'h77)!=8'h77)||sample_seq!=previous_seq+1)$fatal(1,"AUX disturbed main continuity");
   for(integer g=0;g<3;g=g+1)if(group_data[g*64+:64]!={16'd0,16'(500+100*g),16'd0,16'(100+100*g)})$fatal(1,"AUX changed main FIR data");
  end
  previous_seq=sample_seq;@(negedge clk_rf);native_seq=native_seq+1;native_gsc=native_gsc+4;
 end endtask
 task request_source(input [1:0] s);begin source_shadow=s;commit=1;tick();commit=0;if(rejected)$fatal(1,"valid source rejected");end endtask
 task acknowledge;begin source_feedback=source_request;source_ack=1;tick();source_ack=0;end endtask
 task settle;begin for(integer n=0;n<65;n=n+1)tick();if(!aux_valid||busy)$fatal(1,"no qualified AUX");end endtask
 initial begin
  for(integer c=0;c<8;c=c+1)begin
   logical_to_physical[c*3+:3]=c;near_clip_threshold[c*17+:17]=30000;
   for(integer n=0;n<4;n=n+1)begin
    native_adc_data[(2*c)*64+n*16+:16]=c==3?24000:(c==7?-24000:100+c*100);
    native_adc_data[(2*c+1)*64+n*16+:16]=c==3?-12000:(c==7?12000:0);
   end
  end
  tick();rst=0;repeat(130)tick();check_main=1;
  flush_samples=42;commit=1;tick();commit=0;
  if(!rejected||source_epoch!=0||busy)$fatal(1,"unsafe 42-cycle full-chain flush accepted");
  flush_samples=58;calibration_valid=0;commit=1;tick();commit=0;if(!rejected||source_epoch!=0)$fatal(1,"missing calibration admitted");calibration_valid=3;
  source_shadow=3;commit=1;tick();commit=0;if(!rejected||source_epoch!=0)$fatal(1,"invalid source admitted");
  request_source(1);commit=1;tick();commit=0;if(!rejected||source_epoch!=1)$fatal(1,"busy commit changed identity");acknowledge();settle();
  if(source_role!=2||source_epoch!=1||h_calibration_id!=7||v_calibration_id!=9)$fatal(1,"external identity mapping");
  request_source(2);h_calibration_shadow=71;v_calibration_shadow=91;
  for(integer n=0;n<4;n=n+1)begin
   native_adc_data[6*64+n*16+:16]=0;native_adc_data[7*64+n*16+:16]=0;
   native_adc_data[14*64+n*16+:16]=0;native_adc_data[15*64+n*16+:16]=0;
  end
  acknowledge();
  for(integer n=1;n<=65;n=n+1)begin
   tick();if(group_data[192+:64]!=0)last_dirty=n;
   if(aux_valid&&aux_data!=0)$fatal(1,"AUX history exposed before flush n=%0d data=%h",n,aux_data);
   if(aux_valid&&(aux_seq!=sample_seq||aux_gsc!=sample_gsc))$fatal(1,"AUX timestamp changed");
  end
  if(last_dirty<=42||last_dirty>=58||!aux_valid||source_role!=3||source_epoch!=2||h_calibration_id!=7||v_calibration_id!=9)$fatal(1,"flush/identity boundary dirty=%0d",last_dirty);
  source_feedback=0;#1;if(aux_valid)$fatal(1,"feedback loss not masked");tick();source_feedback=2;tick();if(aux_valid)$fatal(1,"feedback restore bypassed requalification");
  request_source(1);acknowledge();settle();if(h_calibration_id!=71||v_calibration_id!=91)$fatal(1,"new calibration identity");
  native_adc_valid[6]=0;repeat(4)tick();if(aux_valid)$fatal(1,"missing AUX sample remained valid");
  native_adc_valid=65535;repeat(65)tick();if(!aux_valid)$fatal(1,"AUX missing sample recovery");
  calibration_valid=0;#1;if(aux_valid)$fatal(1,"calibration validity ignored");tick();calibration_valid=3;
  binding_valid=0;tick();if(aux_valid||!unbound)$fatal(1,"unbound AUX");binding_valid=1;repeat(65)tick();if(aux_valid)$fatal(1,"rebind without commit");
  request_source(0);acknowledge();repeat(65)tick();if(aux_valid||source_role!=0)$fatal(1,"disabled source");
  request_source(1);repeat(21)tick();if(busy||aux_valid)$fatal(1,"missing ACK did not time out safely");
  request_source(2);acknowledge();repeat(5)tick();source_feedback=0;tick();source_feedback=2;repeat(65)tick();
  if(aux_valid)$fatal(1,"feedback glitch during flush did not require a new switch");
  request_source(2);acknowledge();settle();
  $display("PASS AUX_RECEIVE_GUARD real eight RX FIR tail last_dirty=%0d, main continuity, source roles, identities, missing and feedback requalification",last_dirty);$finish;
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
