// RF-domain observation queue. Full queues drop PDW only, never backpressure
// capture/RAW. Soft capture reset is intentionally not connected to this queue.
module qualified_pdw_queue #(parameter integer PRE_SAMPLES=250,ADDR_W=4,BODY_STATS=0)(
 input wire clk,rst,in_valid,pop_valid,input wire [63:0] pop_token,
 input wire [255:0] event_key,input wire [1023:0] event_header,
 input wire [511:0] event_stats,input wire [191:0] event_peaks,
 input wire [15:0] post_samples,
 output wire [31:0] count,output reg [31:0] dropped,
 output wire [63:0] head_token,output wire [511:0] head_data,output wire pop_ok
);
 import calibrator_contract_pkg::*;
 import capture_event_pkg::*;
 localparam integer DEPTH=1<<ADDR_W;
 localparam [63:0] PRE_TICKS=PRE_SAMPLES*4;
 wire [7:0] range_id=event_header[FRAME_RANGE_ID_OFFSET*8+:8];
 wire identity_ok=event_key[63:32]==0&&event_header[FRAME_CONFIG_ID_OFFSET*8+:32]==event_key[31:0];
 wire selected_ok=identity_ok&&range_id>=1&&range_id<=3;
 wire [1:0] group_index=selected_ok?range_id[1:0]-2'd1:2'd0;
 wire [2:0] v_index={1'b0,group_index}+3'd3;
 wire [31:0] samples=event_header[FRAME_SAMPLE_COUNT_OFFSET*8+:32];
 wire [31:0] body_samples={17'd0,event_stats[290:276]};
 wire stats_geometry=BODY_STATS?(body_samples!=0&&body_samples<=16384&&samples>=body_samples+PRE_SAMPLES):(samples==body_samples);
 wire stats_ok=selected_ok&&stats_geometry&&samples!=0&&samples<=16384&&
  event_stats[297+group_index]&&!event_stats[291+group_index]&&!event_stats[291+v_index];
 wire [64:0] toa={1'b0,event_header[FRAME_GSC_FIRST_OFFSET*8+:64]}+{1'b0,PRE_TICKS};
 wire toa_ok=selected_ok&&!toa[64];
 wire width_ok=BODY_STATS?stats_ok:(selected_ok&&samples<=16384&&samples>PRE_SAMPLES+{16'd0,post_samples});
 wire [31:0] width_ticks=BODY_STATS?(body_samples<<2):((samples-PRE_SAMPLES-{16'd0,post_samples})<<2);
 wire [31:0] hp=event_peaks[group_index*32+:32],vp=event_peaks[v_index*32+:32];
 wire [63:0] energy={18'd0,event_stats[group_index*46+:46]}+{18'd0,event_stats[v_index*46+:46]};
 wire [31:0] flags=(toa_ok?EVENT_TOA_VALID:0)|(width_ok?EVENT_WIDTH_VALID:0)|
  (stats_ok?(EVENT_PEAK_VALID|EVENT_ENERGY_VALID):0)|(selected_ok?EVENT_SELECTED_VALID:0);
 wire formatted_valid;wire [511:0] formatted_data;
 capture_pdw_writer formatter(.clk(clk),.rst(rst),.in_valid(in_valid),.event_ready(1'b1),
  .pulse_id(event_key[255:192]),.owner_epoch(event_key[191:128]),.config_id(event_key[31:0]),
  .toa_gsc(toa[63:0]),.width_ticks(width_ticks),.peak_power(hp>vp?hp:vp),.energy_sum(energy),
  .flags(flags),.selected_range({24'd0,range_id}),.in_ready(),.event_valid(formatted_valid),.rejected(),.event_data(formatted_data));
 reg [511:0] data_mem[0:DEPTH-1];reg [63:0] token_mem[0:DEPTH-1];
 reg [ADDR_W-1:0] rd,wr;reg [ADDR_W:0] occupancy;reg [63:0] next_token;reg exhausted;
 assign count={{(31-ADDR_W){1'b0}},occupancy};
 assign head_token=(!rst&&occupancy!=0)?token_mem[rd]:64'd0;
 assign head_data=(!rst&&occupancy!=0)?data_mem[rd]:512'd0;
 assign pop_ok=!rst&&pop_valid&&occupancy!=0&&pop_token==head_token;
 wire push=formatted_valid&&!exhausted&&(occupancy<DEPTH||pop_ok);
 always @(posedge clk)begin
  if(rst)begin rd<=0;wr<=0;occupancy<=0;dropped<=0;next_token<=1;exhausted<=0;end
  else begin
   if(push)begin
    data_mem[wr]<=formatted_data;token_mem[wr]<=next_token;wr<=wr+1'b1;
    if(next_token==64'hffffffffffffffff)exhausted<=1;else next_token<=next_token+1'b1;
   end else if(formatted_valid&&dropped!=32'hffffffff)dropped<=dropped+1'b1;
   if(pop_ok)rd<=rd+1'b1;
   case({push,pop_ok})2'b10:occupancy<=occupancy+1'b1;2'b01:occupancy<=occupancy-1'b1;default:begin end endcase
  end
 end
endmodule
