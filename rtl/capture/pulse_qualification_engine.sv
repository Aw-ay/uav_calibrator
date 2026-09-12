// Concrete digital qualification pipeline. Payload layout is defined in
// contracts/qualification_payload.json. Actual capture/bank adapter is external.
// Pool -> input register -> normalization -> comparison -> qualification. No ready path
// propagates to ADC: upstream owns joint capture/context resource admission.
module pulse_qualification_engine(
 input wire clk,rst,cancel_all,context_valid,stats_valid,noise_valid,result_ready,
 input wire [255:0] context_key,stats_key,noise_key,
 input wire [1023:0] context_data,
 input wire [511:0] stats_data,
 input wire [255:0] noise_data,
 output wire context_ready,stats_ready,noise_ready,result_valid,
 output reg [255:0] result_key,
 output reg [5:0] qualified,pair_known,pair_pass,
 output reg [47:0] reasons,
 output reg selected_valid,
 output reg [1:0] selected_range,
 output wire context_rejected,stats_rejected,noise_rejected,
 output wire [3:0] occupied
);
 wire pv,pr,pc_ready,pc_reject;
 wire [255:0] pk,pn;wire [1023:0] pc;wire [511:0] ps;
 reg s1_valid,out_valid,duplicate_rejected;
 reg s0_valid,norm_valid;
 reg [255:0] s0_key,s0_noise,norm_key;
 reg [1023:0] s0_context,norm_context;
 reg [511:0] s0_stats,norm_stats;
 reg [467:0] norm_energy;
 reg [275:0] norm_noise_energy;
 reg [5:0] norm_eligible,norm_noise_known;
 reg norm_context_ok;
 wire norm_ready=!norm_valid||s1_ready;
 wire s0_ready=!s0_valid||norm_ready;
 reg [255:0] s1_key;reg [1023:0] s1_context;reg [511:0] s1_stats;
 reg [275:0] s1_noise_energy;
 reg [5:0] s1_noise_known,s1_linear_known,s1_linear_pass,s1_pair_known,s1_pair_pass;
 reg s1_context_ok;
 wire s2_ready=!out_valid||result_ready;
 wire s1_ready=!s1_valid||s2_ready;
 wire duplicate_pipeline=(s0_valid&&s0_key==context_key)||(norm_valid&&norm_key==context_key)||(s1_valid&&s1_key==context_key)||(out_valid&&result_key==context_key);
 assign context_ready=pc_ready&&!duplicate_pipeline;
 assign context_rejected=pc_reject||duplicate_rejected;
 assign pr=s0_ready&&!rst&&!cancel_all;
 assign result_valid=out_valid&&!rst&&!cancel_all;
 pulse_context_pool pool(.clk(clk),.rst(rst),.cancel_all(cancel_all),
  .context_valid(context_valid&&!duplicate_pipeline),.stats_valid(stats_valid),.noise_valid(noise_valid),.result_ready(pr),
  .context_key(context_key),.stats_key(stats_key),.noise_key(noise_key),
  .context_data(context_data),.stats_data(stats_data),.noise_data(noise_data),
  .context_ready(pc_ready),.stats_ready(stats_ready),.noise_ready(noise_ready),.result_valid(pv),
  .result_key(pk),.result_noise(pn),.result_context(pc),.result_stats(ps),
  .context_rejected(pc_reject),.stats_rejected(stats_rejected),.noise_rejected(noise_rejected),.occupied(occupied));
 wire payload_ok=!(|s0_context[1023:264])&&!(|s0_stats[511:300])&&!(|s0_noise[255:198]);
 wire context_ok=payload_ok&&s0_context[261]&&s0_stats[290:276]!=0&&s0_stats[290:276]<=16384;
 wire [275:0] ne;wire [5:0] nk,lk,lp,pairk,pairp;
 wire [467:0] normalized;wire [5:0] eligible;
 genvar c;
 generate for(c=0;c<6;c=c+1)begin: normalize
  wire [45:0] energy=s0_stats[c*46+:46];
  wire [31:0] scale=s0_context[c*32+:32];
  assign normalized[c*78+:78]=energy*scale;
  assign eligible[c]=context_ok&&s0_context[258]&&s0_context[246+c]&&s0_context[252+c]&&!s0_stats[291+c]&&energy!=0&&scale!=0;
 end endgenerate
 noise_window_energy noise_convert(.noise_power(s0_noise[191:0]),.noise_known(s0_noise[197:192]),
  .sample_count(s0_stats[290:276]),.noise_energy(ne),.energy_known(nk));
 range_linearity_normalized linearity(.normalized_energy(norm_energy),.eligible(norm_eligible),
  .common_known(norm_context[262]),.common_pass(norm_context[263]),.tolerance_q16(norm_context[239:224]),
  .pair_known(pairk),.pair_pass(pairp),.linearity_known(lk),.linearity_pass(lp));
 wire [5:0] q;wire [47:0] why;wire sv;wire [1:0] choice;
 range_qualification qualification(.energy(s1_stats[275:0]),.noise_energy(s1_noise_energy),
  .min_snr_q16(s1_context[223:192]),.bad_channels(s1_stats[296:291]),
  .cal_valid(s1_context[251:246]),.noise_valid(s1_noise_known),
  .linearity_known(s1_linear_known),.linearity_pass(s1_linear_pass),
  .context_valid(s1_context_ok),.threshold_valid(s1_context[259]),.rank_valid(s1_context[260]),
  .frozen_stats_done(s1_stats[299:297]),.gain_order(s1_context[245:240]),
  .sample_count(s1_stats[290:276]),.qualified(q),.reasons(why),.selected_valid(sv),.selected_range(choice));
 always @(posedge clk)begin
  if(rst||cancel_all)begin
   s0_valid<=0;norm_valid<=0;s0_key<=0;s0_noise<=0;norm_key<=0;
   s0_context<=0;norm_context<=0;s0_stats<=0;norm_stats<=0;
   norm_energy<=0;norm_noise_energy<=0;norm_eligible<=0;norm_noise_known<=0;norm_context_ok<=0;
   s1_valid<=0;out_valid<=0;duplicate_rejected<=0;
   s1_key<=0;s1_context<=0;s1_stats<=0;s1_noise_energy<=0;s1_noise_known<=0;
   s1_linear_known<=0;s1_linear_pass<=0;s1_pair_known<=0;s1_pair_pass<=0;s1_context_ok<=0;
   result_key<=0;qualified<=0;pair_known<=0;pair_pass<=0;reasons<=0;selected_valid<=0;selected_range<=0;
  end else begin
   duplicate_rejected<=context_valid&&duplicate_pipeline;
   if(s2_ready)begin
    out_valid<=s1_valid;
    if(s1_valid)begin
     result_key<=s1_key;qualified<=q;reasons<=why;selected_valid<=sv;selected_range<=choice;
     pair_known<=s1_pair_known;pair_pass<=s1_pair_pass;
    end
   end
   if(s0_ready)begin
    s0_valid<=pv;
    if(pv)begin s0_key<=pk;s0_context<=pc;s0_stats<=ps;s0_noise<=pn;end
   end
   if(norm_ready)begin
    norm_valid<=s0_valid;
    if(s0_valid)begin
     norm_key<=s0_key;norm_context<=s0_context;norm_stats<=s0_stats;
     norm_energy<=normalized;norm_eligible<=eligible;norm_noise_energy<=ne;norm_noise_known<=nk;norm_context_ok<=context_ok;
    end
   end
   if(s1_ready)begin
    s1_valid<=norm_valid;
    if(norm_valid)begin
     s1_key<=norm_key;s1_context<=norm_context;s1_stats<=norm_stats;s1_noise_energy<=norm_noise_energy;s1_noise_known<=norm_noise_known;
     s1_linear_known<=lk;s1_linear_pass<=lp;s1_pair_known<=pairk;s1_pair_pass<=pairp;s1_context_ok<=norm_context_ok;
    end
   end
  end
 end
endmodule
