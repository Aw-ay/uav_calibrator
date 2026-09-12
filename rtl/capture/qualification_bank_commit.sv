// Normal-mode three-group commit adapter for the actual capture_bank_manager.
// Caller supplies a frozen per-group bank/generation map associated with the
// qualification result; never derives all three generations from a single key.
// Requires exclusive ownership of these banks' stats/publish/discard controls.
module qualification_bank_commit(
 input wire clk,rst,quiesce,request_valid,selected_valid,want_replay,
 input wire [1:0] selected_range,
 input wire [5:0] channel_qualified,bank_ids,
 input wire [63:0] expected_epoch,expected_pulse,
 input wire [191:0] expected_generations,
 input wire [15:0] pending,qualified,
 input wire [1023:0] generation,pulse_id,
 input wire [63:0] owner_epoch,
 output wire request_ready,busy,
 output reg done,rejected,published,
 output reg [3:0] published_bank,
 output reg [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending,
 output reg [1023:0] stats_generation
);
 reg [1:0] state;
 reg [5:0] ids_latched,good_latched;
 reg [191:0] gens_latched;
 reg [63:0] epoch_latched,pulse_latched;
 reg selected_latched,replay_latched;reg [1:0] range_latched;
 wire [5:0] ids=state==0?bank_ids:ids_latched;
 wire [191:0] gens=state==0?expected_generations:gens_latched;
 wire [63:0] epoch=state==0?expected_epoch:epoch_latched;
 wire [63:0] pulse=state==0?expected_pulse:pulse_latched;
 reg identity_match,can_publish;integer g,n,chosen;
 assign busy=state!=0;
 assign request_ready=state==0&&!rst&&!quiesce;
 always @*begin
  identity_match=owner_epoch==epoch;
  for(g=0;g<3;g=g+1)begin
   n=4*g+ids[g*2+:2];
   if(!pending[n]||generation[n*64+:64]!=gens[g*64+:64]||pulse_id[n*64+:64]!=pulse)identity_match=0;
  end
  chosen=0;can_publish=0;
  if(selected_latched&&range_latched<3)begin
   chosen=4*range_latched+ids_latched[range_latched*2+:2];
   can_publish=good_latched[range_latched]&&good_latched[range_latched+3]&&qualified[chosen];
  end
  stats_valid=0;stats_good=0;stats_generation=0;publish=0;replay_pin=0;discard_pending=0;
  if(!rst&&!quiesce&&identity_match)begin
   for(g=0;g<3;g=g+1)begin
    n=4*g+ids_latched[g*2+:2];
    if(state==1)begin
     stats_valid[n]=1;stats_good[n]=good_latched[g]&&good_latched[g+3];
     stats_generation[n*64+:64]=gens_latched[g*64+:64];
    end
    if(state==2)begin
     if(can_publish&&n==chosen)begin publish[n]=1;replay_pin[n]=replay_latched;end
     else discard_pending[n]=1;
    end
   end
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   state<=0;done<=0;rejected<=0;published<=0;published_bank<=0;
   ids_latched<=0;good_latched<=0;gens_latched<=0;epoch_latched<=0;pulse_latched<=0;
   selected_latched<=0;replay_latched<=0;range_latched<=0;
  end else begin
   done<=0;rejected<=0;published<=0;
   if(state==0)begin
    if(request_valid&&request_ready)begin
     if(!identity_match||(selected_valid&&selected_range>=3))rejected<=1;
     else begin
      ids_latched<=bank_ids;good_latched<=channel_qualified;gens_latched<=expected_generations;
      epoch_latched<=expected_epoch;pulse_latched<=expected_pulse;
      selected_latched<=selected_valid;range_latched<=selected_range;replay_latched<=want_replay;state<=1;
     end
    end
   end else if(quiesce||!identity_match)begin state<=0;done<=1;rejected<=1;end
   else if(state==1)state<=2;
   else begin
    state<=0;done<=1;published<=can_publish;
    if(can_publish)published_bank<=chosen[3:0];
   end
  end
 end
endmodule

