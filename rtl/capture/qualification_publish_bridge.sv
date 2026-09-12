// Four retained transaction maps connect qualification to the real bank owner.
// Header payloads are opaque: caller constructs/validates the record ABI.
// Event acceptance releases only this map, never the bank's reader references.
module qualification_publish_bridge(
 input wire clk,rst,quiesce,begin_valid,want_replay,measurement_valid,noise_valid,event_ready,
 input wire [255:0] begin_key,measurement_key,noise_key,
 input wire [1023:0] config_data,
 input wire [511:0] measurement_data,
 input wire [255:0] noise_data,
 input wire [5:0] bank_ids,
 input wire [191:0] bank_generations,
 input wire [3071:0] headers,
 input wire [15:0] pending,qualified,
 input wire [1023:0] generation,pulse_id,
 input wire [63:0] owner_epoch,
 output wire begin_ready,measurement_ready,noise_ready,event_valid,idle,
 output reg begin_rejected,event_published,event_rejected,
 output wire measurement_rejected,noise_rejected,
 output reg [255:0] event_key,
 output reg [3:0] event_bank,
 output reg [1023:0] event_header,
 output reg [63:0] event_generation,event_epoch,
 output wire [15:0] stats_valid,stats_good,publish,replay_pin,discard_pending,
 output wire [1023:0] stats_generation
);
 reg [3:0] used;
 reg [255:0] keys[0:3];reg [5:0] ids[0:3];
 reg [191:0] gens[0:3];reg [3071:0] saved_headers[0:3];reg replay[0:3];
 reg active,event_held;reg [1:0] active_slot;
 reg free_found,duplicate,match_found;reg [1:0] free_slot,match_slot;
 wire engine_ready,result_valid,result_ready,selected_valid;
 wire [255:0] result_key;wire [5:0] channel_qualified;wire [1:0] selected_range;
 wire commit_ready,commit_done,commit_rejected,commit_published;
 wire [3:0] commit_bank;
 integer i;
 always @* begin
  free_found=0;free_slot=0;duplicate=0;match_found=0;match_slot=0;
  for(integer s=0;s<4;s=s+1)begin
   if(!used[s]&&!free_found)begin free_found=1;free_slot=s[1:0];end
   if(used[s]&&keys[s]==begin_key)duplicate=1;
   if(used[s]&&keys[s]==result_key)begin match_found=1;match_slot=s[1:0];end
  end
 end
 wire admission_allowed=free_found&&!duplicate&&!quiesce&&!rst;
 assign begin_ready=admission_allowed&&engine_ready;
 assign event_valid=event_held&&!rst;
 assign idle=(used==0)&&!active&&!event_held;
 wire commit_valid=result_valid&&match_found&&!active&&!event_held&&!rst;
 assign result_ready=commit_ready&&match_found&&!active&&!event_held&&!rst;
 pulse_qualification_engine engine(
  .clk(clk),.rst(rst),.cancel_all(1'b0),.context_valid(begin_valid&&admission_allowed),
  .context_key(begin_key),.context_data(config_data),.context_ready(engine_ready),.context_rejected(),
  .stats_valid(measurement_valid),.stats_key(measurement_key),.stats_data(measurement_data),
  .stats_ready(measurement_ready),.stats_rejected(measurement_rejected),
  .noise_valid(noise_valid),.noise_key(noise_key),.noise_data(noise_data),
  .noise_ready(noise_ready),.noise_rejected(noise_rejected),
  .result_valid(result_valid),.result_ready(result_ready),.result_key(result_key),
  .qualified(channel_qualified),.selected_valid(selected_valid),.selected_range(selected_range),
  .pair_known(),.pair_pass(),.reasons(),.occupied());
 qualification_bank_commit commit(
  .clk(clk),.rst(rst),.quiesce(quiesce),.request_valid(commit_valid),.request_ready(commit_ready),.busy(),
  .selected_valid(selected_valid),.selected_range(selected_range),.channel_qualified(channel_qualified),
  .want_replay(replay[match_slot]),.bank_ids(ids[match_slot]),.expected_generations(gens[match_slot]),
  .expected_epoch(keys[match_slot][191:128]),.expected_pulse(keys[match_slot][255:192]),
  .pending(pending),.qualified(qualified),.generation(generation),.pulse_id(pulse_id),.owner_epoch(owner_epoch),
  .done(commit_done),.rejected(commit_rejected),.published(commit_published),.published_bank(commit_bank),
  .stats_valid(stats_valid),.stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
  .discard_pending(discard_pending),.stats_generation(stats_generation));
 always @(posedge clk)begin
  if(rst)begin
   used<=0;active<=0;active_slot<=0;event_held<=0;begin_rejected<=0;
   event_published<=0;event_rejected<=0;event_key<=0;event_bank<=0;
   event_header<=0;event_generation<=0;event_epoch<=0;
   for(i=0;i<4;i=i+1)begin keys[i]<=0;ids[i]<=0;gens[i]<=0;saved_headers[i]<=0;replay[i]<=0;end
  end else begin
   begin_rejected<=begin_valid&&!begin_ready;
   if(begin_valid&&begin_ready)begin
    used[free_slot]<=1;keys[free_slot]<=begin_key;ids[free_slot]<=bank_ids;
    gens[free_slot]<=bank_generations;saved_headers[free_slot]<=headers;replay[free_slot]<=want_replay;
   end
   if(commit_valid&&commit_ready)begin active<=1;active_slot<=match_slot;end
   // Invalid identity can reject immediately, without the commit's done pulse.
   if(active&&(commit_done||commit_rejected))begin
    active<=0;event_held<=1;event_key<=keys[active_slot];
    event_epoch<=keys[active_slot][191:128];event_rejected<=commit_rejected;
    event_published<=commit_published;event_bank<=0;event_header<=0;event_generation<=0;
    if(commit_published)begin
     event_bank<=commit_bank;
     event_header<=saved_headers[active_slot][commit_bank[3:2]*1024+:1024];
     event_generation<=gens[active_slot][commit_bank[3:2]*64+:64];
    end
   end
   if(event_valid&&event_ready)begin event_held<=0;used[active_slot]<=0;end
  end
 end
endmodule
