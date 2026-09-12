// Native RFDC -> actual eight RX FIR lanes with matching RF sample timestamps.
// Logical-to-physical channel mapping and hardware health are trusted board inputs.
module calibrator_receive_frontend(
 input wire clk_rf,rst,enable,input wire [1023:0] native_adc_data,input wire [15:0] native_adc_valid,
 output wire [15:0] native_adc_ready,input wire [63:0] native_seq,native_gsc,
 input wire common_clock_good,input wire [7:0] mts_locked,
 input wire mapping_valid,input wire [23:0] logical_to_physical,
 input wire [135:0] near_clip_threshold,input wire [7:0] threshold_validated,hard_overrange_event,hard_overrange_known,
 output wire sample_valid,output wire [63:0] sample_seq,sample_gsc,
 output wire [255:0] group_data,output wire [7:0] logical_good,logical_saturated,
 output wire [7:0] physical_good,physical_saturated
);
 wire [511:0] adc_i,adc_q;wire [7:0] adc_valid,rx_valid;
 wire [127:0] rx_i,rx_q;
 wire rx_rst=rst||!enable;
 wire [7:0] clip,missing,threshold_unknown,overrange,overrange_unknown;
 rfdc_stream_adapter native_adapter(.native_data(native_adc_data),.native_valid(native_adc_valid),.native_ready(native_adc_ready),.iq_i(adc_i),.iq_q(adc_q),.iq_valid(adc_valid));
 native_overload_monitor overload(.clk(clk_rf),.rst(rx_rst),.in_valid(1'b1),.gsc_base(native_gsc),.beat_seq(native_seq),
  .iq_i(adc_i),.iq_q(adc_q),.iq_valid(adc_valid),.near_clip_threshold(near_clip_threshold),.threshold_validated(threshold_validated),
  .hard_overrange_event(hard_overrange_event),.hard_overrange_known(hard_overrange_known),.out_valid(),.out_gsc_base(),.out_beat_seq(),
  .near_clip(clip),.near_clip_count(),.missing(missing),.threshold_unknown(threshold_unknown),.hard_overrange(overrange),.hard_overrange_unknown(overrange_unknown));
 reg [63:0] seq_pipe[0:14],gsc_pipe[0:14];
 always @(posedge clk_rf)begin
  if(rx_rst)for(integer n=0;n<15;n=n+1)begin seq_pipe[n]<=0;gsc_pipe[n]<=0;end
  else begin
   seq_pipe[0]<=native_seq;gsc_pipe[0]<=native_gsc;
   for(integer n=1;n<15;n=n+1)begin seq_pipe[n]<=seq_pipe[n-1];gsc_pipe[n]<=gsc_pipe[n-1];end
  end
 end
 assign sample_seq=seq_pipe[14];assign sample_gsc=gsc_pipe[14];assign sample_valid=(&rx_valid)&&!rx_rst;
 genvar c;
 generate for(c=0;c<8;c=c+1)begin: physical
  reg [5:0] quality_holdoff;wire [1:0] sat;
  always @(posedge clk_rf)begin
   if(rx_rst||!adc_valid[c]||!common_clock_good||!mts_locked[c]||clip[c]||threshold_unknown[c]||overrange[c]||overrange_unknown[c])quality_holdoff<=6'd58;
   else if(quality_holdoff!=0)quality_holdoff<=quality_holdoff-1'b1;
  end
  fir_rx_lane fir(.clk(clk_rf),.rst(rx_rst),.in_valid(1'b1),
   .in_i(adc_valid[c]?adc_i[c*64+:64]:64'd0),.in_q(adc_valid[c]?adc_q[c*64+:64]:64'd0),
   .out_valid(rx_valid[c]),.out_i(rx_i[c*16+:16]),.out_q(rx_q[c*16+:16]),.out_sat(sat));
  assign physical_saturated[c]=rx_valid[c]&&(|sat);
  assign physical_good[c]=rx_valid[c]&&quality_holdoff==0&&!physical_saturated[c]&&common_clock_good&&mts_locked[c];
 end endgenerate
 reg map_unique;
 always @*begin
  map_unique=mapping_valid;
  for(integer a=0;a<8;a=a+1)for(integer b=a+1;b<8;b=b+1)
   if(logical_to_physical[a*3+:3]==logical_to_physical[b*3+:3])map_unique=0;
 end
 generate for(c=0;c<4;c=c+1)begin: logical_group
  wire [2:0] h=logical_to_physical[c*3+:3],v=logical_to_physical[(c+4)*3+:3];
  assign group_data[c*64+:64]={rx_q[v*16+:16],rx_i[v*16+:16],rx_q[h*16+:16],rx_i[h*16+:16]};
  assign logical_good[c]=map_unique&&physical_good[h];assign logical_good[c+4]=map_unique&&physical_good[v];
  assign logical_saturated[c]=physical_saturated[h];assign logical_saturated[c+4]=physical_saturated[v];
 end endgenerate
endmodule
