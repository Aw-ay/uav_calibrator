// Beat-local quality observation before the two D2 receive decimators.
// iq_i/iq_q use the canonical channel*64 + lane*16 order from
// rfdc_stream_adapter; lane zero is the earliest sample of the beat.
//
// near_clip is only a calibrated DDC-component magnitude surrogate. It cannot
// prove that the physical ADC did not clip. The calibrated threshold domain is
// 1..32768; zero, an encoding above 32768, or an unvalidated threshold is
// reported as threshold_unknown and never interpreted as a clean observation.
//
// hard_overrange_event must be a time-associated event pulse for this beat.
// The upstream RFDC status bookkeeper owns sticky-status detection/clearing and
// event attribution. hard_overrange_known says which channel event inputs are
// authoritative; this module neither counts sticky-high cycles as samples nor
// invents a clear protocol.
module native_overload_monitor(
 input  wire         clk,
 input  wire         rst,
 input  wire         in_valid,
 input  wire [63:0]  gsc_base,
 input  wire [63:0]  beat_seq,
 input  wire [511:0] iq_i,
 input  wire [511:0] iq_q,
 input  wire [7:0]   iq_valid,
 input  wire [135:0] near_clip_threshold,
 input  wire [7:0]   threshold_validated,
 input  wire [7:0]   hard_overrange_event,
 input  wire [7:0]   hard_overrange_known,
 output reg          out_valid,
 output reg  [63:0]  out_gsc_base,
 output reg  [63:0]  out_beat_seq,
 output reg  [7:0]   near_clip,
 output reg  [23:0]  near_clip_count,
 output reg  [7:0]   missing,
 output reg  [7:0]   threshold_unknown,
 output reg  [7:0]   hard_overrange,
 output reg  [7:0]   hard_overrange_unknown
);
 function automatic [16:0] abs16(input signed [15:0] value);
  begin
   if(value == -16'sd32768) abs16 = 17'd32768;
   else if(value < 0) abs16 = -value;
   else abs16 = value;
  end
 endfunction

 reg [7:0] near_clip_next;
 reg [23:0] count_next;
 reg [7:0] threshold_unknown_next;
 reg [2:0] lane_count;
 reg [16:0] threshold;
 integer channel,lane;
 always @* begin
  near_clip_next=0;
  count_next=0;
  threshold_unknown_next=0;
  lane_count=0;
  threshold=0;
  for(channel=0;channel<8;channel=channel+1) begin
   threshold=near_clip_threshold[channel*17+:17];
   lane_count=0;
   if(!threshold_validated[channel] || threshold==0 || threshold>17'd32768)
    threshold_unknown_next[channel]=1'b1;
   if(iq_valid[channel] && threshold_validated[channel] && threshold!=0 && threshold<=17'd32768) begin
    for(lane=0;lane<4;lane=lane+1)
     if(abs16($signed(iq_i[channel*64+lane*16+:16]))>=threshold ||
        abs16($signed(iq_q[channel*64+lane*16+:16]))>=threshold)
      lane_count=lane_count+1'b1;
    count_next[channel*3+:3]=lane_count;
    near_clip_next[channel]=(lane_count!=0);
   end
  end
 end

 always @(posedge clk) begin
  if(rst) begin
   out_valid<=0;out_gsc_base<=0;out_beat_seq<=0;near_clip<=0;
   near_clip_count<=0;missing<=0;threshold_unknown<=0;
   hard_overrange<=0;hard_overrange_unknown<=0;
  end else begin
   out_valid<=in_valid;
   if(in_valid) begin
    out_gsc_base<=gsc_base;out_beat_seq<=beat_seq;
    near_clip<=near_clip_next;near_clip_count<=count_next;
    missing<=~iq_valid;threshold_unknown<=threshold_unknown_next;
    hard_overrange<=hard_overrange_event & hard_overrange_known;
    hard_overrange_unknown<=~hard_overrange_known;
   end
  end
 end
endmodule
