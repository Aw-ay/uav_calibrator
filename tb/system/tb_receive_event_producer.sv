`timescale 1ns/1ps
module tb_receive_event_producer;
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
 integer bodies=0;
 always @(posedge clk)if(!rst&&body_end_valid)begin
  if(bodies==0&&(body_end_seq!=105||body_end_pulse_id!=1||body_end_owner_epoch!=7||!body_end_precise||body_end_truncated||sample_seq>109))$fatal(1,"body end must precede POST completion");
  if(bodies==1&&(body_end_seq!=145||body_end_pulse_id!=3))$fatal(1,"first overlap body end");
  if(bodies==2&&(body_end_seq!=152||body_end_pulse_id!=4))$fatal(1,"second overlap body end");
  if(bodies==3&&body_end_precise)$fatal(1,"quality abort cannot be precise");
  bodies=bodies+1;
 end
 receive_event_producer #(.PRE_SAMPLES(3)) dut(.*);
 integer starts=0,ends=0;
 always @(posedge clk)begin
  if(!rst&&onset_valid&&onset_ready)begin
   if(starts==0 && (onset_seq!=100||onset_gsc!=1400||onset_pulse_id!=1||onset_config!=123||onset_metadata!=456||onset_noise[197:192]!=63||onset_noise[31:0]!=1||!onset_want_replay||onset_bad_channels!=0))$fatal(1,"causal frozen onset snapshot");
   if(onset_eop_hold!=2)$fatal(1,"frozen resolved hold");
   if(starts==0&&sample_seq!=102)$fatal(1,"onset bound must be two RF cycles");starts=starts+1;
  end
  if(!rst&&eop_event_valid)begin
   if(ends==0 && (eop_event_pulse_id!=1||eop_event_owner_epoch!=7||eop_event_stop!=109||eop_event_bad_channels!=0))$fatal(1,"exclusive EOP plus post");if(ends==1&&(eop_event_pulse_id!=3||eop_event_stop!=175||eop_event_bad_channels!=0))$fatal(1,"first overlapping post context");
   if(ends==2&&(eop_event_pulse_id!=4||eop_event_stop!=182||eop_event_bad_channels!=0))$fatal(1,"second overlapping post context");
   if(ends==3&&(eop_event_pulse_id!=5||eop_event_bad_channels!=63))$fatal(1,"quality failure must survive to EOP");
   ends=ends+1;
  end
 end
 task sample(input integer n,amplitude);begin
  @(negedge clk);sample_seq=n;sample_gsc=1000+4*n;
  for(integer g=0;g<4;g=g+1)group_data[g*64+:64]={16'd0,16'(amplitude),16'd0,16'(amplitude)};
  @(posedge clk);#1;
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(integer n=0;n<100;n=n+1)sample(n,1);
  for(integer n=100;n<105;n=n+1)sample(n,100);
  for(integer n=105;n<120;n=n+1)sample(n,1);
  if(starts!=1||ends!=1||!idle||dropped_onsets!=0)$fatal(1,"producer drain");
  onset_ready=0;for(integer n=120;n<125;n=n+1)sample(n,100);
  for(integer n=125;n<140;n=n+1)sample(n,1);
  if(dropped_onsets!=1||!idle)$fatal(1,"unavailable context rejected without late retry");
  onset_ready=1;post_samples=30;
  for(integer n=140;n<145;n=n+1)sample(n,100);
  for(integer n=145;n<147;n=n+1)sample(n,1);
  for(integer n=147;n<152;n=n+1)sample(n,100);
  for(integer n=152;n<190;n=n+1)sample(n,1);
  if(starts!=3||ends!=3||!idle)$fatal(1,"overlapping post windows did not drain");
  for(integer n=190;n<195;n=n+1)sample(n,100);
  logical_good=0;sample(195,1);logical_good=255;
  for(integer n=196;n<235;n=n+1)sample(n,1);
  if(starts!=4||ends!=4||bodies!=4||!idle||dropped_onsets!=1)$fatal(1,"quality abort drain");
  $display("PASS receive event producer actual detector causal noise timestamps post window admission");$finish;
 end
endmodule
