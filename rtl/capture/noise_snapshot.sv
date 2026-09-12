// Six logical channels, same order as pulse_range_statistics.
// offpulse_enable is an explicit qualified off-pulse assertion, not merely
// !detector.active. Caller excludes settling, FIR tails and uncertain onset.
// Snapshot observes state BEFORE this edge's estimator update (causal).
module noise_snapshot(
 input wire clk,rst,clear_estimate,offpulse_enable,snapshot_request,result_ready,
 input wire [95:0] iq_i,iq_q,
 input wire [5:0] sample_good,
 input wire [4:0] ewma_shift,
 input wire [31:0] max_age_cycles,
 input wire [63:0] pulse_id,context_version,
 output wire snapshot_ready,
 output reg result_valid,rejected,
 output reg [63:0] result_id,result_context,
 output reg [191:0] noise_power,
 output reg [5:0] noise_known
);
 reg [31:0] estimate[0:5],age[0:5];
 reg [5:0] seeded;
 reg [63:0] estimate_context;
 reg [4:0] estimate_shift;
 wire changed=context_version!=estimate_context||ewma_shift!=estimate_shift;
 assign snapshot_ready=!result_valid&&!clear_estimate;
 wire [31:0] power[0:5];
 genvar g;
 generate for(g=0;g<6;g=g+1)begin: lane
  wire signed [15:0] i=iq_i[g*16+:16],q=iq_q[g*16+:16];
  wire [31:0] i2=$signed(i)*$signed(i),q2=$signed(q)*$signed(q);
  assign power[g]=i2+q2;
 end endgenerate
 integer c;
 always @(posedge clk)begin
  if(rst)begin
   result_valid<=0;rejected<=0;result_id<=0;result_context<=0;
   noise_power<=0;noise_known<=0;seeded<=0;estimate_context<=0;estimate_shift<=0;
   for(c=0;c<6;c=c+1)begin estimate[c]<=0;age[c]<=32'hffffffff;end
  end else begin
   rejected<=0;estimate_context<=context_version;estimate_shift<=ewma_shift;
   if(result_valid&&result_ready)result_valid<=0;
   for(c=0;c<6;c=c+1)begin
    if(clear_estimate||changed)begin seeded[c]<=0;estimate[c]<=0;age[c]<=32'hffffffff;end
    else if(age[c]!=32'hffffffff)age[c]<=age[c]+1'b1;
    if(!clear_estimate&&offpulse_enable&&sample_good[c])begin
     age[c]<=0;seeded[c]<=1;
     if(!seeded[c]||changed)estimate[c]<=power[c];
     else if(power[c]>=estimate[c])estimate[c]<=estimate[c]+((power[c]-estimate[c])>>ewma_shift);
     else estimate[c]<=estimate[c]-((estimate[c]-power[c])>>ewma_shift);
    end
   end
   if(snapshot_request)begin
    if(!snapshot_ready)rejected<=1;
    else begin
     result_valid<=1;result_id<=pulse_id;result_context<=context_version;
     for(c=0;c<6;c=c+1)begin
      noise_power[c*32+:32]<=estimate[c];
      noise_known[c]<=seeded[c]&&!changed&&(max_age_cycles!=0)&&(age[c]<max_age_cycles);
     end
    end
   end
  end
 end
endmodule
