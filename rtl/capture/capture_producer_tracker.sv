// Four producer contexts; no RAW ownership release. All signals are clk-domain.
module capture_producer_tracker #(parameter integer ADDR_W=14)(
 input wire clk,rst,block_new_work,onset_valid,output wire onset_ready,
 output reg onset_accepted,onset_rejected,
 input wire [63:0] onset_seq,onset_gsc,onset_pulse_id,config_version,input wire onset_want_replay,
 input wire [1023:0] onset_config,onset_metadata,input wire [255:0] onset_noise,input wire [5:0] onset_bad_channels,
 output wire primary_trigger,output wire [63:0] primary_onset,primary_pulse_id,input wire primary_admitted,
 input wire [15:0] armed,pending,frozen,truncated,input wire [1023:0] generation,pulse_id,start_seq,
 input wire [16*(ADDR_W+1)-1:0] sample_count,input wire [63:0] owner_epoch,
 input wire eop_event_valid,input wire [63:0] eop_event_pulse_id,eop_event_owner_epoch,eop_event_stop,
 input wire [5:0] eop_event_bad_channels,output reg eop_accepted,eop_rejected,
 output reg [15:0] eop_valid,output reg [1023:0] eop_stop,eop_generation,
 output wire request_valid,input wire request_ready,
 output wire request_want_replay,output wire [255:0] request_key,request_noise,output wire [1023:0] request_config,request_metadata,
 output wire [5:0] request_bank_ids,request_bad_channels,output wire [191:0] request_generations,request_starts,
 output wire [44:0] request_counts,output wire [63:0] request_onset_seq,request_onset_gsc,
 output wire error_valid,error_bound,input wire error_ready,output wire [255:0] error_key,
 output wire [5:0] error_bank_ids,output wire [191:0] error_generations,output wire [7:0] error_reason,
 output reg [3:0] occupied,output wire producers_idle,
 output reg [31:0] onset_reject_count,eop_reject_count,context_error_count
);
 import calibrator_contract_pkg::*;
 localparam FREE=0,WAIT_OWNER=1,TRACK=2,READY=3,ERROR=4;
 reg [2:0] state[0:3];reg [255:0] keys[0:3],noises[0:3];reg [1023:0] configs[0:3],metas[0:3],before_gens[0:3];
 reg [63:0] onsets[0:3],gscs[0:3],stops[0:3];reg [5:0] ids[0:3],bad[0:3];reg [191:0] gens[0:3],starts[0:3];reg [44:0] counts[0:3];
 reg has_eop[0:3],eop_sent[0:3],want_replays[0:3],bound[0:3];reg [7:0] errors[0:3];
 reg offer_hold,error_hold;reg [1:0] offer_slot,error_slot;
 reg free_found,waiting,duplicate,bank_available,eop_found;
 reg [1:0] free_slot,eop_slot;reg [63:0] eop_onset;
 reg [3:0] bind_ok,live_ok,all_pending,window_ok;
 reg [5:0] bind_ids[0:3],trunc_bad[0:3];reg [191:0] bind_gens[0:3];
 integer s,g,b,n,match_count;reg [63:0] common_start;reg [ADDR_W:0] common_count;
 wire admit=onset_valid&&onset_ready;
 assign onset_ready=!rst&&!block_new_work&&free_found&&!waiting&&!duplicate&&bank_available&&config_version[63:32]==0;
 assign primary_trigger=admit;assign primary_onset=onset_seq;assign primary_pulse_id=onset_pulse_id;
 assign request_valid=offer_hold&&!rst;
 assign request_want_replay=want_replays[offer_slot];
 assign request_key=keys[offer_slot];assign request_config=configs[offer_slot];assign request_noise=noises[offer_slot];assign request_metadata=metas[offer_slot];
 assign request_bank_ids=ids[offer_slot];assign request_generations=gens[offer_slot];assign request_bad_channels=errors[offer_slot]==4?6'h3f:bad[offer_slot];
 assign request_starts=starts[offer_slot];assign request_counts=counts[offer_slot];assign request_onset_seq=onsets[offer_slot];assign request_onset_gsc=gscs[offer_slot];
 assign error_bound=bound[error_slot];
 assign error_valid=error_hold&&!rst;assign error_key=keys[error_slot];assign error_bank_ids=ids[error_slot];assign error_generations=gens[error_slot];assign error_reason=errors[error_slot];
 assign producers_idle=!(|occupied)&&!offer_hold&&!error_hold;
 always @*begin
  free_found=0;free_slot=0;waiting=0;duplicate=0;occupied=0;
  bank_available=(|armed[3:0])&&(|armed[7:4])&&(|armed[11:8]);
  eop_found=0;eop_slot=0;eop_onset=0;
  bind_ok=0;live_ok=0;all_pending=0;window_ok=0;
  common_start=0;common_count=0;match_count=0;n=0;
  for(s=0;s<4;s=s+1)begin
   occupied[s]=state[s]!=FREE;
   if(state[s]==FREE&&!free_found)begin free_found=1;free_slot=s[1:0];end
   if(state[s]==WAIT_OWNER)waiting=1;
   if(state[s]!=FREE&&keys[s][255:192]==onset_pulse_id&&keys[s][191:128]==owner_epoch)duplicate=1;
   if((state[s]==WAIT_OWNER||state[s]==TRACK)&&keys[s][255:192]==eop_event_pulse_id&&keys[s][191:128]==eop_event_owner_epoch&&!has_eop[s])begin eop_found=1;eop_slot=s[1:0];eop_onset=onsets[s];end
   bind_ok[s]=owner_epoch==keys[s][191:128];bind_ids[s]=0;bind_gens[s]=0;
   live_ok[s]=owner_epoch==keys[s][191:128];all_pending[s]=1;window_ok[s]=1;trunc_bad[s]=0;
   common_start=start_seq[ids[s][1:0]*64+:64];common_count=sample_count[ids[s][1:0]*(ADDR_W+1)+:(ADDR_W+1)];
   if(common_count==0||common_count>(1<<ADDR_W)||common_count>16384)window_ok[s]=0;
   for(g=0;g<3;g=g+1)begin
    match_count=0;
    for(b=0;b<4;b=b+1)begin
     n=g*4+b;
     if(generation[n*64+:64]==before_gens[s][n*64+:64]+64'd1&&pulse_id[n*64+:64]==keys[s][255:192]&&!armed[n]&&!frozen[n])begin
      match_count=match_count+1;bind_ids[s][g*2+:2]=b[1:0];bind_gens[s][g*64+:64]=generation[n*64+:64];
     end
    end
    if(match_count!=1)bind_ok[s]=0;
    n=g*4+ids[s][g*2+:2];
    if(generation[n*64+:64]!=gens[s][g*64+:64]||pulse_id[n*64+:64]!=keys[s][255:192]||frozen[n]||armed[n])live_ok[s]=0;
    if(!pending[n])all_pending[s]=0;
    if(start_seq[n*64+:64]!=common_start||sample_count[n*(ADDR_W+1)+:(ADDR_W+1)]!=common_count)window_ok[s]=0;
    trunc_bad[s][g]=truncated[n];trunc_bad[s][g+3]=truncated[n];
   end
  end
 end
 wire eop_new=!eop_found&&admit&&eop_event_pulse_id==onset_pulse_id&&eop_event_owner_epoch==owner_epoch;
 wire [1:0] selected_eop_slot=eop_new?free_slot:eop_slot;
 wire [63:0] selected_eop_onset=eop_new?onset_seq:eop_onset;
 integer j,k,slot_n,error_delta;reg chosen;
 always @(posedge clk)begin
  if(rst)begin
   eop_valid<=0;eop_stop<=0;eop_generation<=0;offer_hold<=0;error_hold<=0;offer_slot<=0;error_slot<=0;
   onset_accepted<=0;onset_rejected<=0;eop_accepted<=0;eop_rejected<=0;
   onset_reject_count<=0;eop_reject_count<=0;context_error_count<=0;
   for(j=0;j<4;j=j+1)begin
    state[j]<=FREE;keys[j]<=0;noises[j]<=0;configs[j]<=0;metas[j]<=0;before_gens[j]<=0;
    onsets[j]<=0;gscs[j]<=0;stops[j]<=0;ids[j]<=0;bad[j]<=0;gens[j]<=0;starts[j]<=0;counts[j]<=0;has_eop[j]<=0;eop_sent[j]<=0;errors[j]<=0;want_replays[j]<=0;bound[j]<=0;
   end
  end else begin
   onset_accepted<=0;onset_rejected<=0;eop_accepted<=0;eop_rejected<=0;error_delta=0;eop_valid<=0;eop_stop<=0;eop_generation<=0;
   if(onset_valid)begin
    if(admit)begin
     state[free_slot]<=WAIT_OWNER;keys[free_slot]<={onset_pulse_id,owner_epoch,64'd0,config_version};want_replays[free_slot]<=onset_want_replay;bound[free_slot]<=0;
     configs[free_slot]<=onset_config;noises[free_slot]<=onset_noise;metas[free_slot]<=onset_metadata;
     metas[free_slot][FRAME_PULSE_ID_OFFSET*8+:64]<=onset_pulse_id;metas[free_slot][FRAME_CONFIG_ID_OFFSET*8+:32]<=config_version[31:0];
     onsets[free_slot]<=onset_seq;gscs[free_slot]<=onset_gsc;bad[free_slot]<=onset_bad_channels;before_gens[free_slot]<=generation;
     has_eop[free_slot]<=0;eop_sent[free_slot]<=0;ids[free_slot]<=0;gens[free_slot]<=0;starts[free_slot]<=0;counts[free_slot]<=0;errors[free_slot]<=0;onset_accepted<=1;
    end else begin onset_rejected<=1;if(onset_reject_count!=32'hffffffff)onset_reject_count<=onset_reject_count+1'b1;end
   end
   for(j=0;j<4;j=j+1)begin
    if(state[j]==WAIT_OWNER)begin
     if(!primary_admitted||!bind_ok[j])begin state[j]<=ERROR;errors[j]<=!primary_admitted?1:2;error_delta=error_delta+1;end
     else begin state[j]<=TRACK;ids[j]<=bind_ids[j];gens[j]<=bind_gens[j];keys[j][127:64]<=bind_gens[j][63:0];bound[j]<=1;end
    end
    if(state[j]==TRACK)begin
     if(!live_ok[j])begin state[j]<=ERROR;errors[j]<=3;error_delta=error_delta+1;end
     else begin
      bad[j]<=bad[j]|trunc_bad[j];
      if(has_eop[j]&&!eop_sent[j])begin
       eop_sent[j]<=1;
       for(k=0;k<3;k=k+1)begin slot_n=k*4+ids[j][k*2+:2];eop_valid[slot_n]<=1;eop_stop[slot_n*64+:64]<=stops[j];eop_generation[slot_n*64+:64]<=gens[j][k*64+:64];end
      end
      if(all_pending[j])begin
       // Matching PENDING banks must drain through normal all-bad qualification.
       // A geometry error does not invalidate the retained ownership identity.
       begin
        state[j]<=READY;
        if(!window_ok[j])begin bad[j]<=6'h3f;want_replays[j]<=0;errors[j]<=4;error_delta=error_delta+1;end
        for(k=0;k<3;k=k+1)begin slot_n=k*4+ids[j][k*2+:2];starts[j][k*64+:64]<=start_seq[slot_n*64+:64];counts[j][k*15+:15]<=sample_count[slot_n*(ADDR_W+1)+:(ADDR_W+1)];end
       end
      end
     end
    end
   end
   if(error_delta!=0)begin
    if({1'b0,context_error_count}+error_delta>33'h0ffffffff)context_error_count<=32'hffffffff;
    else context_error_count<=context_error_count+error_delta;
   end
   if(eop_event_valid)begin
    if((eop_found||eop_new)&&eop_event_stop>selected_eop_onset)begin
     has_eop[selected_eop_slot]<=1;stops[selected_eop_slot]<=eop_event_stop;
     bad[selected_eop_slot]<=(eop_new?onset_bad_channels:bad[selected_eop_slot])|eop_event_bad_channels| ((!eop_new&&state[selected_eop_slot]==TRACK)?trunc_bad[selected_eop_slot]:6'd0);eop_accepted<=1;
    end else begin eop_rejected<=1;if(eop_reject_count!=32'hffffffff)eop_reject_count<=eop_reject_count+1'b1;end
   end
   if(!offer_hold)begin
    chosen=0;
    for(j=0;j<4;j=j+1)if(state[j]==READY&&!chosen)begin offer_hold<=1;offer_slot<=j[1:0];chosen=1;end
   end else if(request_ready)begin offer_hold<=0;state[offer_slot]<=FREE;end
   if(!error_hold)begin
    chosen=0;
    for(j=0;j<4;j=j+1)if(state[j]==ERROR&&!chosen)begin error_hold<=1;error_slot<=j[1:0];chosen=1;end
   end else if(error_ready)begin error_hold<=0;state[error_slot]<=FREE;end
  end
 end
endmodule

