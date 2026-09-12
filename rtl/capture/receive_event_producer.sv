// Causal detector/noise producer. Never stalls the ADC stream. Four contexts
// retain independent post windows; failed onset admission is counted, not retried late.
module receive_event_producer #(parameter integer PRE_SAMPLES=250)(
 input wire clk,rst,enable,block_new_work,time_valid,
 input wire sample_valid,input wire [63:0] sample_seq,sample_gsc,input wire [255:0] group_data,input wire [7:0] logical_good,
 input wire [1:0] detector_range,input wire detector_validated,input wire [32:0] on_power,off_power,
 input wire [13:0] eop_hold,max_body,input wire [15:0] post_samples,
 input wire noise_enable,input wire [4:0] noise_shift,input wire [31:0] noise_max_age,
 input wire [63:0] owner_epoch,config_version,input wire [1023:0] config_data,metadata,input wire want_replay,
 output wire onset_valid,input wire onset_ready,output wire [63:0] onset_seq,onset_gsc,onset_pulse_id,
 output wire [1023:0] onset_config,onset_metadata,output wire [255:0] onset_noise,
 output wire [5:0] onset_bad_channels,output wire onset_want_replay,
 output reg eop_event_valid,output reg [63:0] eop_event_pulse_id,eop_event_owner_epoch,eop_event_stop,
 output reg [5:0] eop_event_bad_channels,output wire idle,output reg [31:0] dropped_onsets,
 output wire detector_active
);
 localparam integer HISTORY=PRE_SAMPLES+3;
 wire [5:0] good={logical_good[6:4],logical_good[2:0]};
 wire selected_good=detector_range<3&&logical_good[detector_range]&&logical_good[detector_range+4];
 wire [63:0] selected_iq=detector_range<3?group_data[detector_range*64+:64]:64'd0;
 wire det_onset,det_event,det_precise,det_truncated;wire [63:0] det_onset_seq,det_end_seq;
 wire [32:0] unused_power;wire [3:0] det_reason;
 pulse_detector detector(.clk(clk),.rst(rst),.sample_valid(sample_valid),.time_valid(time_valid),.source_valid(selected_good),
  .sample_seq(sample_seq),.iq(selected_iq),.cfg_enable(enable&&!block_new_work),.cfg_validated(detector_validated&&detector_range<3),
  .cfg_on_power(on_power),.cfg_off_power(off_power),.cfg_eop_hold(eop_hold),.cfg_max_body(max_body),
  .noise_qualified(1'b0),.cfg_noise_shift(noise_shift),.active(detector_active),.onset_valid(det_onset),.event_valid(det_event),
  .event_precise(det_precise),.event_truncated(det_truncated),.onset_seq(det_onset_seq),.event_onset_seq(),.event_end_seq(det_end_seq),
  .event_reason(det_reason),.sample_power(unused_power),.noise_power(),.noise_valid(),.onset_count(),.pulse_count(),.abort_count());
 wire [95:0] ni,nq;wire [5:0] current_bad=~good|{6{!sample_valid||!time_valid}};
 wire [2:0] quiet_group;
 genvar g;
 generate for(g=0;g<3;g=g+1)begin: noise_inputs
  assign ni[g*16+:16]=group_data[g*64+:16];assign nq[g*16+:16]=group_data[g*64+16+:16];
  assign ni[(g+3)*16+:16]=group_data[g*64+32+:16];assign nq[(g+3)*16+:16]=group_data[g*64+48+:16];
  wire signed [15:0] hi=group_data[g*64+:16],hq=group_data[g*64+16+:16],vi=group_data[g*64+32+:16],vq=group_data[g*64+48+:16];
  wire [31:0] h2=hi*hi,q2=hq*hq,v2=vi*vi,w2=vq*vq;
  assign quiet_group[g]=({1'b0,h2}+{1'b0,q2}+{1'b0,v2}+{1'b0,w2})<off_power;
 end endgenerate
 reg [31:0] quiet_count;
 wire quiet=sample_valid&&time_valid&&(&good)&&(&quiet_group)&&!detector_active&&!det_onset;
 wire noise_ready,noise_valid,noise_rejected;wire [191:0] noise_power;wire [5:0] noise_known;
 reg [63:0] next_id,previous_gsc;
 reg [HISTORY-1:0] bad_history[0:5];wire [5:0] pre_bad;
 generate for(g=0;g<6;g=g+1)begin: pre_quality
  assign pre_bad[g]=|bad_history[g];
 end endgenerate
 reg [3:0] used,accepted,stop_known;reg [1:0] detector_slot,offer_slot;reg offer_pending,detector_bound;
 reg [63:0] ids[0:3],epochs[0:3],onsets[0:3],gscs[0:3],stops[0:3];
 reg [1023:0] configs[0:3],metas[0:3];reg [5:0] bad[0:3];reg [15:0] posts[0:3];reg replay_wanted[0:3];
 reg free_found,finish_found;reg [1:0] free_slot,finish_slot;
 always @*begin
  free_found=0;free_slot=0;finish_found=0;finish_slot=0;
  for(integer s=0;s<4;s=s+1)begin
   if(!used[s]&&!free_found)begin free_found=1;free_slot=s;end
   if(used[s]&&accepted[s]&&stop_known[s]&&sample_valid&&sample_seq>=stops[s]-1&&!finish_found)begin finish_found=1;finish_slot=s;end
  end
 end
 wire allocate=det_onset&&free_found&&noise_ready&&!block_new_work&&!offer_pending&&next_id!=64'hffffffffffffffff;
 noise_snapshot noise(.clk(clk),.rst(rst),.clear_estimate(!enable),
  .offpulse_enable(noise_enable&&quiet&&quiet_count>=PRE_SAMPLES+58),.snapshot_request(allocate),.result_ready(1'b1),
  .iq_i(ni),.iq_q(nq),.sample_good(good&{6{sample_valid}}),.ewma_shift(noise_shift),.max_age_cycles(noise_max_age),
  .pulse_id(next_id),.context_version(config_version),.snapshot_ready(noise_ready),.result_valid(noise_valid),.rejected(noise_rejected),
  .result_id(),.result_context(),.noise_power(noise_power),.noise_known(noise_known));
 assign onset_valid=offer_pending&&noise_valid&&!block_new_work;
 assign onset_seq=onsets[offer_slot];assign onset_gsc=gscs[offer_slot];assign onset_pulse_id=ids[offer_slot];
 assign onset_config=configs[offer_slot];assign onset_metadata=metas[offer_slot];assign onset_noise={58'd0,noise_known,noise_power};
 assign onset_bad_channels=bad[offer_slot];assign onset_want_replay=replay_wanted[offer_slot];
 assign idle=used==0&&!offer_pending&&!detector_active;
 always @(posedge clk)begin
  if(rst)begin
   used<=0;accepted<=0;stop_known<=0;detector_slot<=0;offer_slot<=0;offer_pending<=0;detector_bound<=0;
   next_id<=1;previous_gsc<=0;quiet_count<=0;dropped_onsets<=0;eop_event_valid<=0;eop_event_pulse_id<=0;eop_event_owner_epoch<=0;eop_event_stop<=0;eop_event_bad_channels<=0;
   for(integer c=0;c<6;c=c+1)bad_history[c]<={HISTORY{1'b1}};
   for(integer s=0;s<4;s=s+1)begin ids[s]<=0;epochs[s]<=0;onsets[s]<=0;gscs[s]<=0;stops[s]<=0;configs[s]<=0;metas[s]<=0;bad[s]<=0;posts[s]<=0;replay_wanted[s]<=0;end
  end else begin
   eop_event_valid<=0;previous_gsc<=sample_gsc;
   if(!quiet)quiet_count<=0;else if(quiet_count!=32'hffffffff)quiet_count<=quiet_count+1'b1;
   for(integer c=0;c<6;c=c+1)bad_history[c]<={bad_history[c][HISTORY-2:0],current_bad[c]};
   for(integer s=0;s<4;s=s+1)if(used[s]&&(!stop_known[s]||sample_seq<stops[s]))bad[s]<=bad[s]|current_bad;
   if(det_onset)begin
    detector_bound<=allocate;
    if(next_id!=64'hffffffffffffffff)next_id<=next_id+1'b1;
    if(!allocate)dropped_onsets<=dropped_onsets+1'b1;
    else begin
     used[free_slot]<=1;accepted[free_slot]<=0;stop_known[free_slot]<=0;detector_slot<=free_slot;offer_slot<=free_slot;offer_pending<=1;
     ids[free_slot]<=next_id;epochs[free_slot]<=owner_epoch;onsets[free_slot]<=det_onset_seq;gscs[free_slot]<=previous_gsc;
     configs[free_slot]<=config_data;metas[free_slot]<=metadata;bad[free_slot]<=pre_bad|current_bad;posts[free_slot]<=post_samples;replay_wanted[free_slot]<=want_replay;
    end
   end
   if(offer_pending&&noise_valid)begin
    offer_pending<=0;
    if(onset_valid&&onset_ready)accepted[offer_slot]<=1;
    else begin used[offer_slot]<=0;detector_bound<=0;dropped_onsets<=dropped_onsets+1'b1;end
   end
   if(det_event&&detector_bound)begin
    stop_known[detector_slot]<=1;stops[detector_slot]<=det_end_seq+posts[detector_slot];
    if(!det_precise||det_truncated||det_end_seq+posts[detector_slot]<det_end_seq)bad[detector_slot]<=6'h3f;
    detector_bound<=0;
   end
   if(finish_found)begin
    eop_event_valid<=1;eop_event_pulse_id<=ids[finish_slot];eop_event_owner_epoch<=epochs[finish_slot];eop_event_stop<=stops[finish_slot];
    eop_event_bad_channels<=bad[finish_slot]|((sample_seq<stops[finish_slot])?current_bad:6'd0);used[finish_slot]<=0;accepted[finish_slot]<=0;stop_known[finish_slot]<=0;
   end
  end
 end
endmodule
