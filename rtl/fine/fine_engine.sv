// One frozen H/V RAW bank, one natural B128 pass, 32 retained logical samples.
// Fine never supplies ready to the ADC. The owner must retain its analysis lease
// through done: cancellation drains outstanding physical RAM requests first.
module fine_engine #(parameter integer READ_LATENCY_B=1)(
 input wire clk,rst,abort,job_valid,output wire job_ready,
 input wire [13:0] start_ptr,input wire [14:0] sample_count,coarse_start,coarse_end,
 input wire [63:0] noise,top_signal,peak_power,input wire [1:0] source_good,noise_known,
 input wire [383:0] job_header,
 output wire ram_en,output wire [12:0] ram_addr,input wire [127:0] ram_data,
 output reg result_valid,input wire result_ready,output reg [1023:0] result_data,
 output wire busy,output reg done,error
);
 localparam IDLE=0,START=1,SCAN=2,CANDIDATE=3,PEEK=4,PEEK_WAIT=5,SQUARE=6,POWER=7,
  SELECT=8,SOLVE=11,SOLVE_WAIT=12,ADVANCE=13,RETIRE_PREP=14,RETIRE=15,
  SUM_WAIT=20,GATHER=21,FINAL_START=22,FINAL_WAIT=23,OUTPUT=24,CANCEL=31;
 reg causality_bad;reg [3:0] include_now;reg [5:0] segment_now;
 reg [4:0] state;reg [14:0] total,a,b,received,processed,k,first,last,query;
 reg [14:0] lo_a,lo_b,hi_a,hi_b;reg [13:0] origin;reg signed [16:0] evaluated;
 reg [63:0] noises,tops,peaks;reg [383:0] header;reg [1:0] good,known;
 reg [31:0] thresholds[0:1];reg [255:0] powers[0:1];reg [1:0] selector;
 reg [31:0] edge_index[0:3];reg [15:0] edge_quality[0:3];reg [3:0] edge_ok;
 reg [5:0] crossings[0:3];reg [31:0] squares[0:3];
 reg [1:0] timing;reg [31:0] edge_flags;reg [3:0] query_bin;reg [3759:0] saved_bins;
 wire reader_ready,reader_busy,reader_done,reader_reject,cache_ready,stats_job_ready;
 wire launch=state==START&&reader_ready&&cache_ready&&stats_job_ready&&!abort;
 wire cancel=abort||state==CANCEL;
 wire geometry=sample_count>=1&&sample_count<=16384&&coarse_start<coarse_end&&coarse_end<=sample_count;
 assign busy=state!=IDLE;assign job_ready=state==IDLE&&!rst&&!abort;
 wire word_valid,word_ready,word_first,word_last;wire [127:0] word_data;wire [1:0] word_mask;wire [14:0] word_index;
 b_port_reader_128 #(.READ_LATENCY_B(READ_LATENCY_B)) reader(.clk(clk),.rst(rst),.abort(cancel),
  .desc_valid(launch),.desc_ready(reader_ready),.start_ptr(origin),.sample_count(total),
  .ram_en(ram_en),.ram_addr(ram_addr),.ram_data(ram_data),.word_valid(word_valid),.word_ready(word_ready),
  .word_data(word_data),.word_mask(word_mask),.word_first(word_first),.word_last(word_last),.word_index(word_index),
  .done(reader_done),.rejected(reader_reject),.busy(reader_busy));
 wire sample_valid,sample_last,cache_busy,cache_done,cache_error,stats_ready;
 wire [127:0] sample_data;wire [1:0] lane_count;wire [14:0] sample_index;wire [5:0] occupancy;
 wire tail_resolved=processed==total&&evaluated>=$signed({2'b0,total})-2;
 wire retire_now=state==SCAN&&sample_valid&&((processed-sample_index>=29)||tail_resolved);
 wire sample_ready=retire_now&&stats_ready&&!cancel&&!causality_bad;
 wire peek_req_ready,peek_valid,peek_found;wire [63:0] peek_data;wire [14:0] peek_result_index;
 fine_sample_cache_2 cache(.clk(clk),.rst(rst),.abort(cancel),.job_valid(launch),.job_ready(cache_ready),
  .job_count(total),.job_odd(origin[0]),.word_valid(word_valid),.word_ready(word_ready),.word_data(word_data),
  .word_mask(word_mask),.word_index(word_index),.word_first(word_first),.word_last(word_last),
  .sample_valid(sample_valid),.sample_ready(sample_ready),.sample_data(sample_data),.sample_index(sample_index),
  .sample_last(sample_last),.lane_count(lane_count),.occupancy(occupancy),.busy(cache_busy),.done(cache_done),.error(cache_error),
  .peek_req_valid(state==PEEK),.peek_req_ready(peek_req_ready),.peek_index(query),
  .peek_valid(peek_valid),.peek_ready(state==PEEK_WAIT),.peek_found(peek_found),.peek_data(peek_data),.peek_result_index(peek_result_index));
 wire sums_valid,sums_error;wire signed [47:0] bin_real,bin_imag,hv_real,hv_imag;
 wire [31:0] bin_center_twice;wire [14:0] bin_count,hv_count,body_count_h,body_count_v;
 wire [45:0] bin_energy_now,bin_energy_prev,hv_energy_h,hv_energy_v,body_energy_h,body_energy_v;
 fine_segment_accumulator_2 stats(.clk(clk),.rst(rst),.abort(cancel),.job_valid(launch),.job_ready(stats_job_ready),.job_count(total),
  .sample_valid(retire_now&&!cancel&&!causality_bad),.sample_ready(stats_ready),.sample_data(sample_data),.sample_index(sample_index),
  .sample_last(sample_last),.lane_count(lane_count),.body_keep(include_now),.segment_h(segment_now),.segment_v(segment_now),
  .result_valid(sums_valid),.result_release(state==OUTPUT&&result_ready),.error(sums_error),.query_bin(query_bin),
  .bin_real(bin_real),.bin_imag(bin_imag),.bin_center_twice(bin_center_twice),.bin_count(bin_count),
  .bin_energy_now(bin_energy_now),.bin_energy_prev(bin_energy_prev),.hv_real(hv_real),.hv_imag(hv_imag),
  .hv_energy_h(hv_energy_h),.hv_energy_v(hv_energy_v),.hv_count(hv_count),
  .body_energy_h(body_energy_h),.body_energy_v(body_energy_v),.body_count_h(body_count_h),.body_count_v(body_count_v));
 wire solver_ready,solver_valid,solver_ok;wire [15:0] solver_quality;wire [31:0] solver_index;
 wire [2:0] off=k-first;wire [3:0] points=last-first+1'b1;
 fine_edge_solver #(.FAST_MATH(1)) solver(.clk(clk),.rst(rst),.abort(cancel),.req_valid(state==SOLVE),.req_ready(solver_ready),
  .power_window(powers[selector[1]]),.point_count(points),.bracket_offset(off),.bracket_index(k),
  .threshold(thresholds[selector[1]]),.noise(noises[selector[1]*32+:32]),.rising(!selector[0]),
  .result_valid(solver_valid),.result_ready(state==SOLVE_WAIT),.edge_valid(solver_ok),.quality(solver_quality),
  .index_q16(solver_index),.two_q16(),.fit_q16(),.variance_two_q32(),.variance_fit_q32());
 wire final_ready,final_valid;wire [63:0] means,snrs,freq;wire [127:0] chirp;
 wire [31:0] hv_phase;wire [1:0] snr_sat;wire [2:0] spectral_valid;wire [23:0] spectral_quality;
 fine_finalize #(.FAST_MATH(1)) finalize(.clk(clk),.rst(rst),.abort(cancel),.job_valid(state==FINAL_START),.job_ready(final_ready),
  .bin_data(saved_bins),.body_energy({body_energy_v,body_energy_h}),.body_count({body_count_v,body_count_h}),
  .hv_real(hv_real),.hv_imag(hv_imag),.hv_energy_h(hv_energy_h),.hv_energy_v(hv_energy_v),.hv_count(hv_count),
  .noise(noises),.timing_valid(timing),.result_valid(final_valid),.result_ready(state==FINAL_WAIT),
  .mean_power(means),.snr_q16(snrs),.frequency_hz(freq),.chirp_hz_per_s(chirp),.hv_phase_q31(hv_phase),
  .snr_saturated(snr_sat),.valid_mask(spectral_valid),.quality(spectral_quality));
 function automatic in_window(input [14:0] at,input falling);
  in_window=total>1&&at>=(falling?lo_b:lo_a)&&at<=(falling?hi_b:hi_a);
 endfunction
 wire [31:0] p0=powers[selector[1]][off*32+:32];wire [3:0] off1={1'b0,off}+4'd1;
 wire [31:0] p1=powers[selector[1]][off1*32+:32];wire [31:0] threshold=thresholds[selector[1]];
 wire crossing=selector[0]?(p0>=threshold&&threshold>p1):(p0<threshold&&threshold<=p1);
 wire [1:0] prior_good={good[1]&&known[1]&&tops[63:32]!=0&&({2'b0,tops[63:32]}>={noises[63:32],2'b0}),
                       good[0]&&known[0]&&tops[31:0]!=0&&({2'b0,tops[31:0]}>={noises[31:0],2'b0})};
 integer p,s,l;reg [1:0] timing_now;reg [31:0] flags_now;reg [14:0] at_index;
 reg [31:0] body_first;reg signed [31:0] prefix_last;reg [31:0] midpoint,boundary;
 wire want0=processed>=4&&in_window(processed-15'd4,1'b0)||processed>=4&&in_window(processed-15'd4,1'b1);
 wire want1=processed>=3&&in_window(processed-15'd3,1'b0)||processed>=3&&in_window(processed-15'd3,1'b1);
 wire [1:0] scan_step=received-processed>=2&&!want1?2'd2:2'd1;
 always @* begin
  include_now=0;timing_now=0;flags_now=0;causality_bad=0;segment_now=0;
  body_first=0;prefix_last=0;midpoint=0;boundary=0;at_index=0;
  for(p=0;p<2;p=p+1)begin
   flags_now[p*16+:16]=edge_quality[2*p]|edge_quality[2*p+1];
   if(crossings[2*p]>1||crossings[2*p+1]>1)flags_now[p*16+:16]=flags_now[p*16+:16]|16'd48;
   if(!good[p])flags_now[p*16+:16]=flags_now[p*16+:16]|16'd128;
   if(!known[p]||tops[p*32+:32]==0||({2'b0,tops[p*32+:32]}<{noises[p*32+:32],2'b0}))flags_now[p*16+:16]=flags_now[p*16+:16]|16'd1;
   timing_now[p]=edge_ok[2*p]&&edge_ok[2*p+1]&&edge_index[2*p]<edge_index[2*p+1]&&prior_good[p];
  end
  for(l=0;l<2;l=l+1)begin
   at_index=sample_index+l;midpoint=({17'd0,at_index}*2-1)*8;
   for(s=1;s<8;s=s+1)begin boundary={17'd0,a}*16+({17'd0,b}-{17'd0,a})*2*s;if(at_index!=0&&midpoint>=boundary)segment_now[l*3+:3]=s;end
   for(p=0;p<2;p=p+1)begin
    body_first=((edge_index[2*p]+32'd65535)>>16)+4;prefix_last=$signed({17'd0,lo_b})-32'sd4;
    if(prior_good[p]&&l<lane_count)begin
     if(total>1&&evaluated<$signed({2'b0,hi_a}))begin
      if(at_index>=lo_a+4)causality_bad=1;
     end else if(edge_ok[2*p]&&at_index>=body_first)begin
      if(total>1&&evaluated<$signed({2'b0,hi_b}))begin
       if($signed({17'd0,at_index})>prefix_last)causality_bad=1;else include_now[p*2+l]=1;
      end else if(timing_now[p]&&edge_index[2*p+1][31:16]>=4&&at_index<=edge_index[2*p+1][31:16]-4)include_now[p*2+l]=1;
     end
    end
   end
  end
 end
 always @(posedge clk)begin
  if(rst)begin state<=IDLE;result_valid<=0;done<=0;error<=0;result_data<=0;received<=0;processed<=0;evaluated<=-1;end
  else begin
   done<=0;error<=0;
   if(word_valid&&word_ready)received<=received+(word_mask==3?15'd2:15'd1);
   if(abort&&state!=IDLE)begin state<=CANCEL;result_valid<=0;end
   else if((cache_error||sums_error||reader_reject)&&state!=IDLE&&state!=CANCEL)begin state<=CANCEL;error<=1;end
   else case(state)
    IDLE:if(job_valid&&job_ready)begin
     if(!geometry)begin error<=1;done<=1;end
     else begin
      lo_a<=coarse_start>8?coarse_start-15'd8:15'd0;lo_b<=coarse_end>8?coarse_end-15'd8:15'd0;
      hi_a<=coarse_start+16'd8<sample_count-1?coarse_start+15'd8:sample_count-15'd2;
      hi_b<=coarse_end+16'd8<sample_count-1?coarse_end+15'd8:sample_count-15'd2;
      origin<=start_ptr;total<=sample_count;a<=coarse_start;b<=coarse_end;noises<=noise;tops<=top_signal;peaks<=peak_power;
      header<=job_header;good<=source_good;known<=noise_known;received<=0;processed<=0;evaluated<=-1;edge_ok<=0;
      for(p=0;p<2;p=p+1)thresholds[p]<=noise[p*32+:32]+(top_signal[p*32+:32]>>1);
      for(p=0;p<4;p=p+1)begin edge_index[p]<=0;edge_quality[p]<=p%2?16'd4:16'd2;crossings[p]<=0;end
      state<=START;
     end
    end
    START:if(launch)state<=SCAN;
    SCAN:begin
     if(retire_now&&causality_bad)begin error<=1;state<=CANCEL;end
     else if(sample_ready&&sample_valid&&sample_last)state<=SUM_WAIT;
     else if(processed==total)begin
      if(!tail_resolved)begin k<=evaluated+1;state<=CANDIDATE;end
      else if(!sample_valid)state<=SUM_WAIT;
     end else if(processed<received)begin
      if(want0)begin processed<=processed+1'b1;k<=processed-15'd4;state<=CANDIDATE;end
      else begin
       processed<=processed+scan_step;
       if(processed+scan_step>=5)evaluated<=$signed({2'b0,processed})+$signed({15'd0,scan_step})-17'sd5;
      end
     end
    end
    CANDIDATE:begin
     if(in_window(k,1'b0)||in_window(k,1'b1))begin
      first<=k>3?k-15'd3:15'd0;query<=k>3?k-15'd3:15'd0;last<=k+16'd4<total?k+15'd4:total-15'd1;
      powers[0]<=0;powers[1]<=0;state<=PEEK;
     end else begin evaluated<=$signed({2'b0,k});state<=SCAN;end
    end
    PEEK:if(peek_req_ready)state<=PEEK_WAIT;
    PEEK_WAIT:if(peek_valid)begin
     if(!peek_found||peek_result_index!=query)begin error<=1;state<=CANCEL;end
     else begin
      for(p=0;p<4;p=p+1)squares[p]<=$signed(peek_data[p*16+:16])*$signed(peek_data[p*16+:16]);
      state<=POWER;
     end
    end
    POWER:begin
     powers[0][(query-first)*32+:32]<=squares[0]+squares[1];powers[1][(query-first)*32+:32]<=squares[2]+squares[3];
     if(query==last)begin selector<=0;state<=SELECT;end else begin query<=query+1'b1;state<=PEEK;end
    end
    SELECT:begin
     if(in_window(k,selector[0])&&crossing)begin crossings[selector]<=crossings[selector]+1'b1;state<=SOLVE;end
     else state<=ADVANCE;
    end
    SOLVE:if(solver_ready)state<=SOLVE_WAIT;
    SOLVE_WAIT:if(solver_valid)begin
     if((solver_ok&&(selector[0]||!edge_ok[selector]))||(!solver_ok&&!edge_ok[selector]&&(!selector[0]||crossings[selector]==1)))begin
      edge_ok[selector]<=solver_ok;edge_index[selector]<=solver_index;edge_quality[selector]<=solver_quality;
     end
     state<=ADVANCE;
    end
    ADVANCE:if(selector==3)begin evaluated<=$signed({2'b0,k});state<=SCAN;end else begin selector<=selector+1'b1;state<=SELECT;end
    SUM_WAIT:if(sums_valid&&!reader_busy)begin query_bin<=0;timing<=timing_now;edge_flags<=flags_now;state<=GATHER;end
    GATHER:begin
     saved_bins[query_bin*235+:235]<={bin_energy_prev,bin_energy_now,bin_count,bin_center_twice,bin_imag,bin_real};
     if(query_bin==15)state<=FINAL_START;else query_bin<=query_bin+1'b1;
    end
    FINAL_START:if(final_ready)state<=FINAL_WAIT;
    FINAL_WAIT:if(final_valid)begin
     result_data<=0;result_data[383:0]<=header;result_data[31:0]<=32'h00040001;
     result_data[33:32]<=snr_sat;result_data[319:312]<={3'd0,spectral_valid[2],spectral_valid[1:0],timing};
     for(p=0;p<4;p=p+1)result_data[384+p*32+:32]<=edge_index[p];
     result_data[575:512]<=peaks;result_data[639:576]<=means;result_data[703:640]<=freq;result_data[831:704]<=chirp;
     result_data[863:832]<=hv_phase;result_data[927:864]<=snrs;result_data[959:928]<=edge_flags;result_data[991:960]<={8'd0,spectral_quality};
     result_valid<=1;state<=OUTPUT;
    end
    OUTPUT:if(result_ready)begin result_valid<=0;done<=1;state<=IDLE;end
    CANCEL:if(!reader_busy)begin result_valid<=0;done<=1;state<=IDLE;end
    default:begin state<=CANCEL;error<=1;end
   endcase
  end
 end
endmodule
