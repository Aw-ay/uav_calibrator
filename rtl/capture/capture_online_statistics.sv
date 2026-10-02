// Atomically reserve one online context with capture onset. Retain results by
// full epoch/pulse identity until qualification accepts or producer fails.
module capture_online_statistics(
 input wire clk,rst,sample_valid,input wire [63:0] sample_seq,input wire [255:0] group_data,
 input wire [5:0] sample_good,input wire onset_valid,output wire onset_ready,
 input wire [127:0] onset_key,input wire [63:0] onset_seq,
 input wire [191:0] onset_noise,input wire [13:0] onset_eop_hold,
 input wire body_end_valid,input wire [127:0] body_end_key,input wire [63:0] body_end_seq,
 input wire cancel_valid,input wire [127:0] cancel_key,
 input wire [127:0] query_key,output reg query_valid,input wire query_ready,
 output reg [191:0] query_tops,output reg [511:0] query_stats,output reg [191:0] query_peaks,
 output reg [7:0] query_error,output wire idle
);
 wire power_valid;wire [63:0] power_seq;wire [191:0] power_data;wire [5:0] power_good;
 receive_power_pipeline powers(.clk(clk),.rst(rst),.sample_valid(sample_valid),.time_valid(1'b1),.sample_seq(sample_seq),.group_data(group_data),
  .logical_good({1'b0,sample_good[5:3],1'b0,sample_good[2:0]}),.*);
 wire [3:0] occupied,result_valid;reg [3:0] result_ready,canceled;
 wire [511:0] result_key;wire [59:0] result_count;wire [1103:0] result_energy;
 wire [767:0] result_peak,result_top_signal;wire [23:0] result_bad;wire [31:0] result_error;
 wire start_eligible;
 assign onset_ready=start_eligible&&power_valid;
 assign idle=occupied==0;
 online_body_statistics stats(.clk(clk),.rst(rst),.sample_valid(power_valid),.sample_seq(power_seq),.sample_power(power_data),.sample_good(power_good),
  .start_valid(onset_valid&&onset_ready),.start_ready(),.start_eligible(start_eligible),.start_accepted(),.start_rejected(),.start_slot(),
  .start_key(onset_key),.onset_seq(onset_seq),.noise_power(onset_noise),.eop_hold(onset_eop_hold),
  .end_valid(body_end_valid),.end_key(body_end_key),.end_seq(body_end_seq),.end_accepted(),.end_rejected(),.*);
 always @*begin
  query_tops=0;query_valid=0;query_stats=0;query_peaks=0;query_error=0;result_ready=0;
  for(integer s=0;s<4;s=s+1)begin
   if(result_valid[s])begin
    if(canceled[s]||(cancel_valid&&result_key[s*128+:128]==cancel_key))result_ready[s]=1;
    else if(result_key[s*128+:128]==query_key)begin
     query_tops=result_top_signal[s*192+:192];query_valid=1;query_peaks=result_peak[s*192+:192];query_error=result_error[s*8+:8];
     query_stats[275:0]=result_energy[s*276+:276];query_stats[290:276]=result_count[s*15+:15];
     query_stats[296:291]=result_bad[s*6+:6];query_stats[299:297]=3'b111;
     result_ready[s]=query_ready;
    end
   end
  end
 end
 always @(posedge clk)begin
  if(rst)canceled<=0;
  else for(integer s=0;s<4;s=s+1)begin
   if(!occupied[s]||result_ready[s])canceled[s]<=0;
   else if(cancel_valid&&result_key[s*128+:128]==cancel_key)canceled[s]<=1;
  end
 end
endmodule
