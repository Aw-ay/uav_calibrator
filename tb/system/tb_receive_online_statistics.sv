`timescale 1ns/1ps
module tb_receive_online_statistics;
 parameter integer HOLD=256,LENGTH=27;
 reg clk=0,rst=1,enable=1,block_new_work=0,time_valid=1,sample_valid=1;always #4 clk=~clk;
 reg [63:0] sample_seq=0,sample_gsc=0;reg [255:0] group_data=0;reg [7:0] logical_good=255;
 reg [1:0] detector_range=0;reg detector_validated=1;reg [32:0] on_power=1000,off_power=100;
 reg [13:0] eop_hold=2,max_body=100;reg [15:0] post_samples=4;reg noise_enable=1;reg [4:0] noise_shift=2;reg [31:0] noise_max_age=1000;
 reg [63:0] owner_epoch=7,config_version=9;reg [1023:0] config_data=123,metadata=456;reg want_replay=1;
 wire onset_valid;reg onset_ready=1;wire [63:0] onset_seq,onset_gsc,onset_pulse_id;wire [1023:0] onset_config,onset_metadata;wire [255:0] onset_noise;wire [5:0] onset_bad_channels;wire onset_want_replay;
 wire eop_event_valid;wire [63:0] eop_event_pulse_id,eop_event_owner_epoch,eop_event_stop;wire [5:0] eop_event_bad_channels;wire idle,detector_active;wire [31:0] dropped_onsets;
 wire [13:0] onset_eop_hold;
 wire body_end_valid,body_end_precise,body_end_truncated;
 wire [63:0] body_end_pulse_id,body_end_owner_epoch,body_end_seq;
 wire [3:0] body_end_reason;
 receive_event_producer #(.PRE_SAMPLES(3)) dut(.*);
 wire power_valid;wire [63:0] power_seq;wire [191:0] power_data;wire [5:0] power_good;
 receive_power_pipeline powers(.*);
 wire stats_ready;wire [3:0] occupied,result_valid;reg [3:0] result_ready=0;
 wire [511:0] result_key;wire [59:0] result_count;wire [1103:0] result_energy;
 wire [767:0] result_peak,result_top_signal;wire [23:0] result_bad;wire [31:0] result_error;
 wire start_accepted,start_rejected,end_accepted,end_rejected;wire [1:0] start_slot;
 wire start_eligible;
 online_body_statistics stats(.clk(clk),.rst(rst),.sample_valid(power_valid),.sample_seq(power_seq),.sample_power(power_data),.sample_good(power_good),
  .start_valid(onset_valid&&onset_ready),.start_ready(stats_ready),.start_accepted(start_accepted),.start_rejected(start_rejected),.start_slot(start_slot),
  .start_key({owner_epoch,onset_pulse_id}),.onset_seq(onset_seq),.noise_power(onset_noise[191:0]),.eop_hold(onset_eop_hold),
  .end_valid(body_end_valid),.end_key({body_end_owner_epoch,body_end_pulse_id}),.end_seq(body_end_seq),.end_accepted(end_accepted),.end_rejected(end_rejected),.*);
 integer starts=0,ends=0,body_at=-1,raw_at=-1,result_at=-1;
 always @(posedge clk)if(!rst)begin
  if(result_valid!=0&&result_at<0)result_at=sample_seq;
  if(onset_valid&&onset_ready)begin
   if(!stats_ready||onset_eop_hold!=(HOLD==0?125:HOLD))$fatal(1,"onset reservation/hold mismatch");
   starts=starts+1;
  end
  if(start_rejected||end_rejected)$fatal(1,"causal context rejected");
  if(body_end_valid)begin
   if(body_end_seq!=100+LENGTH||body_end_owner_epoch!=7||body_end_pulse_id!=1||!body_end_precise||body_end_truncated)$fatal(1,"body identity/end");
   body_at=sample_seq;
   if(body_at-(100+LENGTH)>(HOLD==0?125:HOLD)+2)$fatal(1,"EOP transport exceeds two RF clocks");
  end
  if(eop_event_valid)begin
   if(eop_event_stop!=100+LENGTH+500)$fatal(1,"RAW POST geometry changed");
   raw_at=sample_seq;ends=ends+1;
  end
 end
 task sample(input integer n,amplitude);begin
  @(negedge clk);sample_seq=n;sample_gsc=1000+4*n;
  for(integer g=0;g<4;g=g+1)group_data[g*64+:64]={16'd0,16'(amplitude),16'd0,16'(amplitude)};
  @(posedge clk);#1;
 end endtask
 initial begin
  eop_hold=HOLD;max_body=15000;post_samples=500;
  repeat(3)@(negedge clk);rst=0;
  for(integer n=0;n<100;n=n+1)sample(n,1);
  for(integer n=100;n<100+LENGTH;n=n+1)sample(n,100);
  for(integer n=100+LENGTH;n<100+LENGTH+300;n=n+1)sample(n,1);
  if(result_at<0||result_at>100+LENGTH+275)$fatal(1,"online readiness exceeds conservative bound");
  if(starts!=1||result_valid!=1||body_at<0||raw_at!=-1)$fatal(1,"statistics must finish before POST capture");
  if(result_key[127:0]!={64'd7,64'd1}||result_count[14:0]!=LENGTH||result_bad!=0||result_error!=0)$fatal(1,"body statistics identity/count/status");
  for(integer c=0;c<6;c=c+1)begin
   if(result_energy[c*46+:46]!=LENGTH*10000||result_peak[c*32+:32]!=10000||result_top_signal[c*32+:32]!=(LENGTH<4?0:9999))$fatal(1,"body-only energy peak TOP c=%0d E=%0d TOP=%0d",c,result_energy[c*46+:46],result_top_signal[c*32+:32]);
  end
  for(integer n=100+LENGTH+300;n<100+LENGTH+510;n=n+1)sample(n,1);
  if(ends!=1||raw_at<=body_at||result_valid!=1)$fatal(1,"held statistics independent of RAW POST");
  result_ready=1;sample(100+LENGTH+510,1);result_ready=0;
  if(occupied!=0)$fatal(1,"statistics acknowledgement");
  $display("PASS actual detector -> body-end -> six IQ powers -> online statistics HOLD=%0d LENGTH=%0d body=%0d raw=%0d",HOLD,LENGTH,body_at,raw_at);$finish;
 end
endmodule
