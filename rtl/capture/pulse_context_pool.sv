// Four independent immutable join slots. Logical contexts are NOT RAM banks:
// upstream must bind each full identity to its actual owner and generation.
// Fixed capacities are those of pulse_context_join; no multi-bank transaction
// identity or calibration ABI is invented here.
module pulse_context_pool(
 input wire clk,rst,cancel_all,context_valid,stats_valid,noise_valid,result_ready,
 input wire [255:0] context_key,stats_key,noise_key,
 input wire [1023:0] context_data,
 input wire [511:0] stats_data,
 input wire [255:0] noise_data,
 output wire context_ready,stats_ready,noise_ready,result_valid,
 output wire [255:0] result_key,result_noise,
 output wire [1023:0] result_context,
 output wire [511:0] result_stats,
 output reg context_rejected,
 output wire stats_rejected,noise_rejected,
 output wire [3:0] occupied
);
 wire [3:0] done,sr,nr;
 wire [255:0] keys[0:3],noises[0:3];
 wire [1023:0] contexts[0:3];wire [511:0] statistics[0:3];
 integer free_slot,stats_slot,noise_slot,candidate;
 integer i,idx;
 reg duplicate_context;
 reg unmatched_stats,unmatched_noise;
 reg locked;reg [1:0] selected,round_robin;
 always @*begin
  free_slot=-1;stats_slot=-1;noise_slot=-1;candidate=-1;duplicate_context=0;idx=0;
  for(i=0;i<4;i=i+1)begin
   if(!occupied[i]&&free_slot==-1)free_slot=i;
   if(occupied[i]&&keys[i]==context_key)duplicate_context=1;
   if(occupied[i]&&keys[i]==stats_key)stats_slot=i;
   if(occupied[i]&&keys[i]==noise_key)noise_slot=i;
   idx=(round_robin+i)%4;
   if(done[idx]&&candidate==-1)candidate=idx;
  end
 end
 assign context_ready=!rst&&!cancel_all&&free_slot!=-1&&!duplicate_context;
 assign stats_ready=!rst&&!cancel_all;
 assign noise_ready=!rst&&!cancel_all;
 assign result_valid=locked&&done[selected]&&!rst&&!cancel_all;
 assign result_key=keys[selected];assign result_context=contexts[selected];
 assign result_stats=statistics[selected];assign result_noise=noises[selected];
 assign stats_rejected=unmatched_stats||(|sr);
 assign noise_rejected=unmatched_noise||(|nr);
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: slot
  pulse_context_join joiner(.clk(clk),.rst(rst),.cancel(cancel_all),
   .context_valid(context_valid&&context_ready&&free_slot==g),
   .stats_valid(stats_valid&&stats_ready&&stats_slot==g),
   .noise_valid(noise_valid&&noise_ready&&noise_slot==g),
   .result_ready(result_ready&&result_valid&&selected==g),
   .context_key(context_key),.stats_key(stats_key),.noise_key(noise_key),
   .context_data(context_data),.stats_data(stats_data),.noise_data(noise_data),
   .context_ready(),.stats_ready(),.noise_ready(),.result_valid(done[g]),
   .busy(occupied[g]),.result_key(keys[g]),.result_context(contexts[g]),
   .result_stats(statistics[g]),.result_noise(noises[g]),
   .context_rejected(),.stats_rejected(sr[g]),.noise_rejected(nr[g]),.aborted());
 end endgenerate
 always @(posedge clk)begin
  if(rst||cancel_all)begin
   context_rejected<=0;unmatched_stats<=0;unmatched_noise<=0;
   locked<=0;selected<=0;round_robin<=0;
  end else begin
   context_rejected<=context_valid&&!context_ready;
   unmatched_stats<=stats_valid&&stats_ready&&stats_slot==-1;
   unmatched_noise<=noise_valid&&noise_ready&&noise_slot==-1;
   if(result_valid&&result_ready)begin locked<=0;round_robin<=selected+2'd1;end
   else if(!locked&&candidate!=-1)begin locked<=1;selected<=candidate[1:0];end
  end
 end
endmodule
