// Sufficient statistics for a single Fine H/V job; no per-sample CORDIC.
// Edge controller supplies final/conservative body membership and frozen bins.
// Two arithmetic stages + accumulator, one logical sample per accepted clock.
// No result is visible until the last input and both stages have drained.
module fine_segment_accumulator(
 input wire clk,rst,abort,job_valid,output wire job_ready,input wire [14:0] job_count,
 input wire sample_valid,output wire sample_ready,input wire [63:0] sample_data,
 input wire [14:0] sample_index,input wire sample_last,input wire [1:0] body_keep,
 input wire [2:0] segment_h,segment_v,
 output reg result_valid,input wire result_release,output reg error,
 input wire [3:0] query_bin,
 output wire signed [47:0] bin_real,bin_imag,output wire [31:0] bin_center_twice,
 output wire [14:0] bin_count,output wire [45:0] bin_energy_now,bin_energy_prev,
 output reg signed [47:0] hv_real,hv_imag,output reg [45:0] hv_energy_h,hv_energy_v,
 output reg [14:0] hv_count,output reg [45:0] body_energy_h,body_energy_v,
 output reg [14:0] body_count_h,body_count_v
);
 reg active,closing;reg [14:0] expected,total;
 reg signed [15:0] previous_i[0:1],previous_q[0:1];reg [1:0] previous_valid;
 reg [31:0] previous_power[0:1];
 wire signed [15:0] now_i[0:2],now_q[0:2],ref_i[0:2],ref_q[0:2];
 assign now_i[0]=sample_data[15:0];assign now_q[0]=sample_data[31:16];
 assign now_i[1]=sample_data[47:32];assign now_q[1]=sample_data[63:48];
 assign now_i[2]=now_i[0];assign now_q[2]=now_q[0];
 assign ref_i[0]=previous_i[0];assign ref_q[0]=previous_q[0];
 assign ref_i[1]=previous_i[1];assign ref_q[1]=previous_q[1];
 assign ref_i[2]=now_i[1];assign ref_q[2]=now_q[1];
 reg signed [31:0] ii[0:2],qq[0:2],qi[0:2],iq[0:2];
 reg [31:0] square_i[0:1],square_q[0:1];
 reg v1,v2;reg [2:0] use1,use2;reg [1:0] keep1,keep2;
 reg [2:0] sh1,sv1,sh2,sv2;reg [31:0] center1,center2;
 reg signed [32:0] real2[0:2],imag2[0:2];
 reg [31:0] power2[0:1],prior1[0:1],prior2[0:1];
 reg signed [47:0] sum_re[0:15],sum_im[0:15];
 reg [31:0] sum_center[0:15];reg [14:0] sum_count[0:15];
 reg [45:0] sum_en[0:15],sum_ep[0:15];
 assign bin_real=sum_re[query_bin];assign bin_imag=sum_im[query_bin];
 assign bin_center_twice=sum_center[query_bin];assign bin_count=sum_count[query_bin];
 assign bin_energy_now=sum_en[query_bin];assign bin_energy_prev=sum_ep[query_bin];
 assign job_ready=!active&&!result_valid&&!rst&&!abort;
 assign sample_ready=active&&!closing&&!rst&&!abort;
 wire take=sample_valid&&sample_ready;
 wire bad=(sample_index!=expected)||(sample_last!=(expected==total-1'b1));
 wire [3:0] bh={1'b0,sh2},bv={1'b1,sv2};
 integer p,b;
 always @(posedge clk)begin
  if(rst||abort)begin
   active<=0;closing<=0;expected<=0;total<=0;result_valid<=0;error<=0;
   v1<=0;v2<=0;previous_valid<=0;
   hv_real<=0;hv_imag<=0;hv_energy_h<=0;hv_energy_v<=0;hv_count<=0;
   body_energy_h<=0;body_energy_v<=0;body_count_h<=0;body_count_v<=0;
   for(b=0;b<16;b=b+1)begin sum_re[b]<=0;sum_im[b]<=0;sum_center[b]<=0;sum_count[b]<=0;sum_en[b]<=0;sum_ep[b]<=0;end
  end else begin
   error<=0;v1<=take&&!bad;v2<=v1;
   if(result_valid&&result_release)result_valid<=0;
   if(take)begin
    if(bad)begin active<=0;closing<=0;v1<=0;v2<=0;error<=1;end
    else begin
     expected<=expected+1'b1;if(sample_last)closing<=1;
     use1<={&body_keep,body_keep&previous_valid};keep1<=body_keep;
     sh1<=segment_h;sv1<=segment_v;center1<={16'd0,sample_index,1'b0}-32'd1;
     previous_valid<=body_keep;
     for(p=0;p<3;p=p+1)begin
      ii[p]<=now_i[p]*ref_i[p];qq[p]<=now_q[p]*ref_q[p];
      qi[p]<=now_q[p]*ref_i[p];iq[p]<=now_i[p]*ref_q[p];
     end
     for(p=0;p<2;p=p+1)begin
      square_i[p]<=now_i[p]*now_i[p];square_q[p]<=now_q[p]*now_q[p];
      // Consecutive accepts must forward the preceding stage-1 power; the
      // retained previous_power is one clock older until stage 2 commits.
      prior1[p]<=v1?(square_i[p]+square_q[p]):previous_power[p];
      previous_i[p]<=now_i[p];previous_q[p]<=now_q[p];
     end
    end
   end
   if(v1)begin
    use2<=use1;keep2<=keep1;sh2<=sh1;sv2<=sv1;center2<=center1;
    for(p=0;p<3;p=p+1)begin
     real2[p]<=$signed({ii[p][31],ii[p]})+$signed({qq[p][31],qq[p]});
     imag2[p]<=$signed({qi[p][31],qi[p]})-$signed({iq[p][31],iq[p]});
    end
    for(p=0;p<2;p=p+1)begin
     power2[p]<=square_i[p]+square_q[p];previous_power[p]<=square_i[p]+square_q[p];
     prior2[p]<=prior1[p];
    end
   end
   if(v2)begin
    if(keep2[0])begin body_energy_h<=body_energy_h+power2[0];body_count_h<=body_count_h+1'b1;end
    if(keep2[1])begin body_energy_v<=body_energy_v+power2[1];body_count_v<=body_count_v+1'b1;end
    if(use2[0])begin
     sum_re[bh]<=sum_re[bh]+real2[0];sum_im[bh]<=sum_im[bh]+imag2[0];
     sum_center[bh]<=sum_center[bh]+center2;sum_count[bh]<=sum_count[bh]+1'b1;
     sum_en[bh]<=sum_en[bh]+power2[0];sum_ep[bh]<=sum_ep[bh]+prior2[0];
    end
    if(use2[1])begin
     sum_re[bv]<=sum_re[bv]+real2[1];sum_im[bv]<=sum_im[bv]+imag2[1];
     sum_center[bv]<=sum_center[bv]+center2;sum_count[bv]<=sum_count[bv]+1'b1;
     sum_en[bv]<=sum_en[bv]+power2[1];sum_ep[bv]<=sum_ep[bv]+prior2[1];
    end
    if(use2[2])begin
     hv_real<=hv_real+real2[2];hv_imag<=hv_imag+imag2[2];
     hv_energy_h<=hv_energy_h+power2[0];hv_energy_v<=hv_energy_v+power2[1];hv_count<=hv_count+1'b1;
    end
   end
   if(active&&closing&&!v1&&!v2)begin active<=0;closing<=0;result_valid<=1;end
   if(job_valid&&job_ready)begin
    if(job_count==0||job_count>16384)error<=1;
    else begin
     active<=1;closing<=0;expected<=0;total<=job_count;previous_valid<=0;v1<=0;v2<=0;
     hv_real<=0;hv_imag<=0;hv_energy_h<=0;hv_energy_v<=0;hv_count<=0;
     body_energy_h<=0;body_energy_v<=0;body_count_h<=0;body_count_v<=0;
     for(b=0;b<16;b=b+1)begin sum_re[b]<=0;sum_im[b]<=0;sum_center[b]<=0;sum_count[b]<=0;sum_en[b]<=0;sum_ep[b]<=0;end
    end
   end
  end
 end
endmodule
