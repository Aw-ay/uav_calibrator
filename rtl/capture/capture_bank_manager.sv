// Low-level owner in clk_rf. All event/return inputs must already cross CDC safely.
// Bank index = 4*(stream_group_id-1)+bank_id. No detector/calibration is inferred.
// eop_stop is absolute exclusive end INCLUDING post samples. Sequence wrap at u64
// rollover requires a quiesced epoch restart. One record and one replay lease/bank.
module capture_bank_manager #(
 parameter integer ADDR_W=14, PRE_SAMPLES=250, DETECTOR_LATENCY=0
)(
 output wire [15:0] replay_leased,
 input wire clk,rst,arm_enable,reset_request,readers_quiescent,output wire quiesce,
 input wire sample_valid,input wire [63:0] sample_seq,
 input wire primary_trigger,input wire [63:0] primary_onset,primary_pulse_id,
 input wire aux_trigger,input wire [63:0] aux_onset,aux_pulse_id,
 input wire [15:0] eop_valid,input wire [1023:0] eop_stop,eop_generation,
 input wire [15:0] discard_pending,
 input wire [15:0] stats_valid,input wire [1023:0] stats_generation,input wire [15:0] stats_good,
 input wire [15:0] publish,replay_pin,
 input wire ack_record,input wire [3:0] ack_record_bank,input wire [63:0] ack_record_epoch,ack_record_generation,
 input wire ack_replay,input wire [3:0] ack_replay_bank,input wire [63:0] ack_replay_epoch,ack_replay_generation,
 output reg [15:0] write_enable,armed,pending,frozen,truncated,qualified,
 output wire [1023:0] start_seq,generation,pulse_id,
 output wire [16*(ADDR_W+1)-1:0] sample_count,
 output reg [63:0] owner_epoch,
 output reg [31:0] rejected_returns,dropped_triggers,
 output reg primary_admitted,aux_admitted
);
 localparam integer DEPTH=1<<ADDR_W,HISTORY=PRE_SAMPLES+DETECTOR_LATENCY+1;
 localparam [2:0] ARMING=0,ARMED=1,CAPTURE=2,PENDING=3,FROZEN=4;
 reg [2:0] state[0:15];reg [63:0] starts[0:15],gens[0:15],pulses[0:15],lasts[0:15],stops[0:15];
 reg [ADDR_W:0] history[0:15],counts[0:15];
 reg [15:0] stop_known,stats_done,record_ref,replay_ref;
 assign replay_leased=replay_ref;
 reg resetting,reset_seen;
 integer i,g,b,pick[0:3],reject_delta;reg eligible;reg [1:0] refs;
 reg [63:0] onset_temp,start_temp,stop_temp;reg stop_now;
 assign quiesce=resetting|reset_request|rst;
 genvar n;generate for(n=0;n<16;n=n+1) begin: descriptors
 assign pulse_id[n*64+:64]=pulses[n];
 assign start_seq[n*64+:64]=starts[n];assign generation[n*64+:64]=gens[n];
 assign sample_count[n*(ADDR_W+1)+:(ADDR_W+1)]=counts[n];
 end endgenerate
 always @* begin
 write_enable=0;armed=0;pending=0;frozen=0;
 for(integer j=0;j<16;j=j+1) begin
 armed[j]=(state[j]==ARMED);pending[j]=(state[j]==PENDING);frozen[j]=(state[j]==FROZEN);
 if(!quiesce && sample_valid) begin
 if(state[j]==ARMING || state[j]==ARMED) write_enable[j]=1;
 if(state[j]==CAPTURE && sample_seq>=starts[j] && sample_seq-starts[j]<DEPTH &&
 (!stop_known[j] || sample_seq<stops[j]) && (!(eop_valid[j] && eop_generation[j*64+:64]==gens[j]) || sample_seq<eop_stop[j*64+:64])) write_enable[j]=1;
 end
 end
 end
 always @(posedge clk) begin
 primary_admitted<=0;aux_admitted<=0;
 if(rst) begin
 owner_epoch<=0;resetting<=0;reset_seen<=0;rejected_returns<=0;dropped_triggers<=0;
 stop_known<=0;stats_done<=0;record_ref<=0;replay_ref<=0;truncated<=0;qualified<=0;
 for(i=0;i<16;i=i+1) begin state[i]<=ARMING;history[i]<=0;counts[i]<=0;starts[i]<=0;gens[i]<=0;pulses[i]<=0;lasts[i]<=0;stops[i]<=0;end
 end else if((reset_request && !reset_seen) || resetting) begin
 reset_seen<=reset_request;
 resetting<=1;
 if(readers_quiescent) begin
 resetting<=0;owner_epoch<=owner_epoch+1;stop_known<=0;stats_done<=0;record_ref<=0;replay_ref<=0;truncated<=0;qualified<=0;
 for(i=0;i<16;i=i+1) begin state[i]<=ARMING;history[i]<=0;counts[i]<=0;end
 end
 // A held request still suppresses RAM writes after drain; do not build history.
 end else if(!quiesce) begin
 if(!reset_request) reset_seen<=0;
 reject_delta=0;
 for(i=0;i<16;i=i+1) begin
 if(state[i]==ARMING || state[i]==ARMED) begin
 if(sample_valid) begin
 lasts[i]<=sample_seq;
 if(history[i]!=0 && sample_seq!=lasts[i]+1) begin history[i]<=1;state[i]<=ARMING;end
 else begin
 if(history[i]<DEPTH) history[i]<=history[i]+1;
 if(arm_enable && DETECTOR_LATENCY>0 && history[i]+1>=HISTORY) state[i]<=ARMED;
 end
 end
 end
 if(state[i]==CAPTURE) begin
 stop_now=stop_known[i]||(eop_valid[i] && eop_generation[i*64+:64]==gens[i]);stop_temp=(eop_valid[i] && eop_generation[i*64+:64]==gens[i])?eop_stop[i*64+:64]:stops[i];
 if(eop_valid[i] && eop_generation[i*64+:64]==gens[i]) begin stops[i]<=stop_temp;stop_known[i]<=1;end
 if(stop_now && (stop_temp<=starts[i] || stop_temp-starts[i]>DEPTH)) begin truncated[i]<=1;end
 // A stored exclusive window is complete regardless of later outside-window gaps.
 if(stop_now && stop_temp<=lasts[i]+1) begin
 state[i]<=PENDING;
 if(stop_temp>starts[i] && stop_temp-starts[i]<=DEPTH) counts[i]<=stop_temp-starts[i];else truncated[i]<=1;
 end else if(sample_valid && sample_seq!=lasts[i]+1) begin state[i]<=PENDING;truncated[i]<=1;end
 else if(sample_valid) begin
 if(sample_seq-starts[i]>=DEPTH) begin state[i]<=PENDING;truncated[i]<=1;end
 else if(write_enable[i]) begin
 lasts[i]<=sample_seq;counts[i]<=sample_seq-starts[i]+1;
 if(stop_now && sample_seq+1>=stop_temp) state[i]<=PENDING;
 end
 end
 end
 if(state[i]==PENDING && stats_valid[i] && stats_generation[i*64+:64]==gens[i]) begin
 stats_done[i]<=1;qualified[i]<=stats_good[i]&&!truncated[i];
 end
 if(state[i]==PENDING && stats_done[i] && discard_pending[i]) begin
 state[i]<=ARMING;history[i]<=0;stats_done[i]<=0;qualified[i]<=0;
 end
 if(state[i]==PENDING && stats_done[i] && publish[i] && !discard_pending[i]) begin
 // Pins are installed on the transition that makes the descriptor visible.
 record_ref[i]<=1;replay_ref[i]<=replay_pin[i]&&qualified[i];state[i]<=FROZEN;
 end
 refs={replay_ref[i],record_ref[i]};
 if(ack_record && ack_record_bank==i) begin
 if(state[i]==FROZEN && record_ref[i] && ack_record_epoch==owner_epoch && ack_record_generation==gens[i]) refs[0]=0;
 else reject_delta=reject_delta+1;
 end
 if(ack_replay && ack_replay_bank==i) begin
 if(state[i]==FROZEN && replay_ref[i] && ack_replay_epoch==owner_epoch && ack_replay_generation==gens[i]) refs[1]=0;
 else reject_delta=reject_delta+1;
 end
 if(state[i]==FROZEN) begin
 record_ref[i]<=refs[0];replay_ref[i]<=refs[1];
 if(refs==0) begin state[i]<=ARMING;history[i]<=0;stats_done[i]<=0;qualified[i]<=0;end
 end
 end
 rejected_returns<=rejected_returns+reject_delta;
 // Admission uses the previous complete contiguous history, never a future sample.
 for(g=0;g<4;g=g+1) begin
 pick[g]=-1;onset_temp=(g==3)?aux_onset:primary_onset;start_temp=onset_temp-PRE_SAMPLES;
 for(b=0;b<4;b=b+1) begin
 i=g*4+b;
 eligible=arm_enable && !quiesce && state[i]==ARMED && onset_temp>=PRE_SAMPLES && onset_temp<=lasts[i]+1 &&
 start_temp<=lasts[i] && lasts[i]-start_temp<history[i] &&
 (!sample_valid || (sample_seq==lasts[i]+1 && sample_seq-start_temp<DEPTH));
 if(pick[g]<0 && eligible) pick[g]=i;
 end
 end
 if(primary_trigger && !(pick[0]>=0 && pick[1]>=0 && pick[2]>=0)) dropped_triggers<=dropped_triggers+1;
 if(aux_trigger && pick[3]<0) dropped_triggers<=dropped_triggers+1+((primary_trigger && !(pick[0]>=0 && pick[1]>=0 && pick[2]>=0))?1:0);
 for(g=0;g<4;g=g+1) begin
 if((g<3 && primary_trigger && pick[0]>=0 && pick[1]>=0 && pick[2]>=0) || (g==3 && aux_trigger && pick[3]>=0)) begin
 i=pick[g];start_temp=((g==3)?aux_onset:primary_onset)-PRE_SAMPLES;
 state[i]<=CAPTURE;starts[i]<=start_temp;pulses[i]<=(g==3)?aux_pulse_id:primary_pulse_id;gens[i]<=gens[i]+1;
 counts[i]<=(sample_valid?sample_seq:lasts[i])-start_temp+1;stop_known[i]<=0;stats_done[i]<=0;qualified[i]<=0;truncated[i]<=0;
 if(g==3) aux_admitted<=1;else primary_admitted<=1;
 end
 end
 end
 end
endmodule
