// Complete captured-window statistics from the existing per-bank A read port.
// One fixed-latency read outstanding per selected bank; no writes or releases.
module capture_statistics_reader #(parameter integer ADDR_W=14)(
 input wire clk,rst,request_valid,output wire request_ready,
 input wire [5:0] request_bank_ids,input wire [191:0] request_generations,
 input wire [255:0] request_key,input wire [5:0] request_bad_channels,
 input wire [15:0] pending,frozen,truncated,
 input wire [1023:0] generation,pulse_id,start_seq,
 input wire [16*(ADDR_W+1)-1:0] sample_count,
 input wire [63:0] owner_epoch,input wire abort_request,
 output reg [15:0] ram_read_enable,output reg [16*ADDR_W-1:0] ram_read_address,
 input wire [1023:0] ram_read_data,input wire [15:0] ram_read_valid,
 output wire busy,output reg result_valid,input wire result_ready,
 output reg [255:0] result_key,output reg [511:0] result_stats,
 output reg [191:0] result_peaks,output reg [5:0] result_bank_ids,
 output reg [191:0] result_generations,output reg [7:0] result_error
);
 localparam IDLE=0,ISSUE=1,RESPONSE=2,FINISH=3;
 reg [1:0] state;
 reg [63:0] start_latched;
 reg [ADDR_W:0] count_latched,index;
 reg [275:0] energies;
 reg [191:0] peaks;
 reg [5:0] bad;
 wire [5:0] ids=state==IDLE?request_bank_ids:result_bank_ids;
 wire [191:0] gens=state==IDLE?request_generations:result_generations;
 wire [255:0] key=state==IDLE?request_key:result_key;
 reg identity_ok,window_ok,responses_ok;reg [5:0] truncated_channels;
 reg [63:0] common_start;reg [ADDR_W:0] common_count;
 integer g,n;
 wire [31:0] powers[0:5];
 genvar c;
 generate for(c=0;c<6;c=c+1)begin: power_lane
  localparam integer GROUP=c%3;
  localparam integer POL=c/3;
  wire [3:0] slot=GROUP*4+result_bank_ids[GROUP*2+:2];
  wire signed [15:0] iv=ram_read_data[slot*64+POL*32+:16];
  wire signed [15:0] qv=ram_read_data[slot*64+POL*32+16+:16];
  wire [31:0] isq=$signed(iv)*$signed(iv),qsq=$signed(qv)*$signed(qv);
  assign powers[c]=isq+qsq;
 end endgenerate
 assign busy=state!=IDLE;
 assign request_ready=state==IDLE&&!result_valid&&!rst&&!abort_request;
 always @*begin
  identity_ok=owner_epoch==key[191:128];window_ok=1;responses_ok=1;truncated_channels=0;
  common_start=start_seq[ids[1:0]*64+:64];common_count=sample_count[ids[1:0]*(ADDR_W+1)+:(ADDR_W+1)];
  if(common_count==0 || common_count>(1<<ADDR_W) || common_count>16384)window_ok=0;
  for(g=0;g<3;g=g+1)begin
   n=g*4+ids[g*2+:2];
   if(!pending[n]||frozen[n]||generation[n*64+:64]!=gens[g*64+:64]||pulse_id[n*64+:64]!=key[255:192])identity_ok=0;
   if(start_seq[n*64+:64]!=common_start||sample_count[n*(ADDR_W+1)+:(ADDR_W+1)]!=common_count)window_ok=0;
   if(!ram_read_valid[n])responses_ok=0;
   truncated_channels[g]=truncated[n];truncated_channels[g+3]=truncated[n];
  end
  if(state!=IDLE && (common_start!=start_latched||common_count!=count_latched))window_ok=0;
  ram_read_enable=0;ram_read_address=0;
  if(state==ISSUE&&!rst&&!abort_request&&identity_ok&&window_ok)begin
   for(integer j=0;j<3;j=j+1)begin
    ram_read_enable[j*4+result_bank_ids[j*2+:2]]=1;
    ram_read_address[(j*4+result_bank_ids[j*2+:2])*ADDR_W+:ADDR_W]=start_latched[ADDR_W-1:0]+index[ADDR_W-1:0];
   end
  end
 end
 integer lane;
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;result_valid<=0;result_key<=0;result_stats<=0;result_peaks<=0;
   result_bank_ids<=0;result_generations<=0;result_error<=0;
   start_latched<=0;count_latched<=0;index<=0;energies<=0;peaks<=0;bad<=0;
  end else begin
   if(result_valid&&result_ready)result_valid<=0;
   if(state==IDLE)begin
    if(request_valid&&request_ready)begin
     result_key<=request_key;result_bank_ids<=request_bank_ids;result_generations<=request_generations;
     result_stats<=0;result_peaks<=0;result_error<=0;energies<=0;peaks<=0;
     bad<=request_bad_channels|truncated_channels;index<=0;
     start_latched<=common_start;count_latched<=common_count;
     if(!identity_ok||!window_ok)begin result_valid<=1;result_error<=!identity_ok?1:2;end
     else state<=ISSUE;
    end
   end else if(abort_request||!identity_ok||!window_ok||(state==RESPONSE&&!responses_ok))begin
    // ISSUE is gated on abort/context; RESPONSE discards the sole in-flight read.
    // No later read exists when this held error is produced.
    state<=IDLE;result_valid<=1;result_stats<=0;result_peaks<=0;
    result_error<=abort_request?4:(!identity_ok?1:(!window_ok?2:3));
   end else begin
    bad<=bad|truncated_channels;
    case(state)
     ISSUE: state<=RESPONSE;
     RESPONSE:begin
      for(lane=0;lane<6;lane=lane+1)begin
       energies[lane*46+:46]<=energies[lane*46+:46]+{14'd0,powers[lane]};
       if(powers[lane]>peaks[lane*32+:32])peaks[lane*32+:32]<=powers[lane];
      end
      if(index+1==count_latched)state<=FINISH;
      else begin index<=index+1'b1;state<=ISSUE;end
     end
     FINISH:begin
      result_stats<=0;
      result_stats[275:0]<=energies;result_stats[290:276]<=count_latched;
      result_stats[296:291]<=bad|truncated_channels;result_stats[299:297]<=3'b111;
      result_peaks<=peaks;result_error<=0;result_valid<=1;state<=IDLE;
     end
     default:state<=IDLE;
    endcase
   end
  end
 end
endmodule
