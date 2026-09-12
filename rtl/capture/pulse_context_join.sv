// Single in-flight immutable join in clk_rf domain. Context must be admitted
// before results. Payloads are opaque: packing is owned by the system adapter.
// Key is {pulse_id,owner_epoch,bank_generation,config_version}, 64 bits each.
// Caller guarantees key uniqueness across reset/cancel/reuse. This block does
// not create epochs, release RAM references or cancel external producers.
module pulse_context_join #(
 parameter integer CONTEXT_BITS=1024,STATS_BITS=512,NOISE_BITS=256
)(
 input wire clk,rst,cancel,context_valid,stats_valid,noise_valid,result_ready,
 input wire [255:0] context_key,stats_key,noise_key,
 input wire [CONTEXT_BITS-1:0] context_data,
 input wire [STATS_BITS-1:0] stats_data,
 input wire [NOISE_BITS-1:0] noise_data,
 output wire context_ready,stats_ready,noise_ready,result_valid,
 output reg busy,
 output reg [255:0] result_key,
 output reg [CONTEXT_BITS-1:0] result_context,
 output reg [STATS_BITS-1:0] result_stats,
 output reg [NOISE_BITS-1:0] result_noise,
 output reg context_rejected,stats_rejected,noise_rejected,aborted
);
 reg got_stats,got_noise;
 assign context_ready=!busy&&!rst&&!cancel;
 // Consume even stale/duplicate result messages, reporting rejection. This
 // prevents a stale head message from blocking a matching result behind it.
 assign stats_ready=!rst&&!cancel;
 assign noise_ready=!rst&&!cancel;
 assign result_valid=busy&&got_stats&&got_noise&&!rst&&!cancel;
 always @(posedge clk)begin
  if(rst)begin
   busy<=0;got_stats<=0;got_noise<=0;result_key<=0;
   result_context<=0;result_stats<=0;result_noise<=0;
   context_rejected<=0;stats_rejected<=0;noise_rejected<=0;aborted<=0;
  end else begin
   context_rejected<=0;stats_rejected<=0;noise_rejected<=0;aborted<=0;
   if(cancel)begin
    aborted<=busy;busy<=0;got_stats<=0;got_noise<=0;
   end else begin
    if(result_valid&&result_ready)begin busy<=0;got_stats<=0;got_noise<=0;end
    if(context_valid)begin
     if(context_ready)begin
      busy<=1;got_stats<=0;got_noise<=0;
      result_key<=context_key;result_context<=context_data;
     end else context_rejected<=1;
    end
    if(stats_valid&&stats_ready)begin
     if(busy&&!got_stats&&stats_key==result_key)begin result_stats<=stats_data;got_stats<=1;end
     else stats_rejected<=1;
    end
    if(noise_valid&&noise_ready)begin
     if(busy&&!got_noise&&noise_key==result_key)begin result_noise<=noise_data;got_noise<=1;end
     else noise_rejected<=1;
    end
   end
  end
 end
endmodule
