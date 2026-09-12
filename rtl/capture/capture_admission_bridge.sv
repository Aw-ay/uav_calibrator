// Owns the onset snapshot while actual completed-window headers are built.
// A malformed time/count is forwarded as all-bad, so qualification discards
// its banks through the normal owner protocol rather than leaking ownership.
module capture_admission_bridge(
 input wire clk,rst,in_valid,output wire in_ready,
 input wire [255:0] in_key,in_noise,input wire [1023:0] in_config,in_metadata,
 input wire [5:0] in_bank_ids,in_bad_channels,input wire [191:0] in_generations,in_start_seq,
 input wire [44:0] in_sample_count,input wire [63:0] in_onset_seq,in_onset_gsc,
 input wire in_want_replay,output wire out_valid,input wire out_ready,
 output reg [255:0] out_key,out_noise,output reg [1023:0] out_config,
 output reg [3071:0] out_headers,output reg [5:0] out_bank_ids,out_bad_channels,
 output reg [191:0] out_generations,output reg out_want_replay,header_error,
 output wire idle
);
 import calibrator_contract_pkg::*;
 localparam EMPTY=0,BUILD=1,COLLECT=2,SEND=3;
 reg [1:0] state;
 reg [1023:0] metadata;
 reg [191:0] starts;
 reg [44:0] counts;
 reg [63:0] onset_seq,onset_gsc;
 wire [2:0] valid,rejected;
 wire [3071:0] built_headers;
 assign in_ready=state==EMPTY&&!rst;
 assign idle=state==EMPTY;
 assign out_valid=state==SEND&&!rst;
 genvar g;
 generate for(g=0;g<3;g=g+1)begin: group_header
  reg [1023:0] group_metadata;
  always @*begin
   group_metadata=metadata;
   // ABI5 logical PRIMARY groups. These are not board GPIO or RF control codes.
   group_metadata[FRAME_STREAM_GROUP_ID_OFFSET*8+:8]=g+1;
   group_metadata[FRAME_RANGE_ID_OFFSET*8+:8]=g+1;
   group_metadata[FRAME_PHYSICAL_ADC_MASK_OFFSET*8+:8]=8'h11<<g;
   group_metadata[FRAME_CHANNEL_MASK_OFFSET*8+:8]=3;
  end
  frame_header_builder builder(.clk(clk),.rst(rst),.request_valid(state==BUILD),.request_ready(),
   .template_header(group_metadata),.sample_count(counts[g*15+:15]),
   .window_start_seq(starts[g*64+:64]),.time_origin_seq(onset_seq),.time_origin_gsc(onset_gsc),
   .result_valid(valid[g]),.result_ready(state==COLLECT),.header_data(built_headers[g*1024+:1024]),.rejected(rejected[g]));
 end endgenerate
 always @(posedge clk)begin
  if(rst)begin
   state<=EMPTY;out_key<=0;out_noise<=0;out_config<=0;out_headers<=0;out_bank_ids<=0;
   out_bad_channels<=0;out_generations<=0;out_want_replay<=0;header_error<=0;
   metadata<=0;starts<=0;counts<=0;onset_seq<=0;onset_gsc<=0;
  end else case(state)
   EMPTY:if(in_valid)begin
    out_key<=in_key;out_noise<=in_noise;out_config<=in_config;out_bank_ids<=in_bank_ids;
    out_bad_channels<=in_bad_channels;out_generations<=in_generations;out_want_replay<=in_want_replay;
    metadata<=in_metadata;starts<=in_start_seq;counts<=in_sample_count;
    onset_seq<=in_onset_seq;onset_gsc<=in_onset_gsc;header_error<=0;state<=BUILD;
   end
   BUILD:state<=COLLECT;
   COLLECT:if(&(valid|rejected))begin
    out_headers<=built_headers;header_error<=|rejected;
    if(|rejected)begin out_bad_channels<=6'h3f;out_want_replay<=0;end
    state<=SEND;
   end
   SEND:if(out_ready)state<=EMPTY;
  endcase
 end
endmodule
