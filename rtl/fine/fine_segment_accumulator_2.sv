// Two chronological H/V samples per cycle. Products32DSP, exact sum of both
// lanes when they target the same bin; lane1 correlates against lane0, not against
// the preceding word. A one-lane terminal transfer never contributes lane1.
module fine_segment_accumulator_2(
 input wire clk,rst,abort,job_valid,output wire job_ready,input wire [14:0] job_count,
 input wire sample_valid,output wire sample_ready,input wire [127:0] sample_data,input wire [1:0] lane_count,
 input wire [14:0] sample_index,input wire sample_last,input wire [3:0] body_keep,
 input wire [5:0] segment_h,segment_v,
 output reg result_valid,input wire result_release,output reg error,input wire [3:0] query_bin,
 output wire signed [47:0] bin_real,bin_imag,output wire [31:0] bin_center_twice,
 output wire [14:0] bin_count,output wire [45:0] bin_energy_now,bin_energy_prev,
 output reg signed [47:0] hv_real,hv_imag,output reg [45:0] hv_energy_h,hv_energy_v,
 output reg [14:0] hv_count,output reg [45:0] body_energy_h,body_energy_v,output reg [14:0] body_count_h,body_count_v
);
 reg active,closing;reg [14:0] expected,total;
 reg signed [15:0] previous_i[0:1],previous_q[0:1];reg [1:0] previous_valid;reg [31:0] previous_power[0:1];
 wire signed [15:0] ni[0:5],nq[0:5],ri[0:5],rq[0:5];
 for(genvar p=0;p<2;p=p+1)begin
  for(genvar l=0;l<2;l=l+1)begin
   assign ni[p*2+l]=sample_data[l*64+p*32+:16];assign nq[p*2+l]=sample_data[l*64+p*32+16+:16];
   if(l==0)begin assign ri[p*2+l]=previous_i[p];assign rq[p*2+l]=previous_q[p];end
   else begin assign ri[p*2+l]=ni[p*2];assign rq[p*2+l]=nq[p*2];end
  end
 end
 for(genvar l=0;l<2;l=l+1)begin
  assign ni[4+l]=ni[l];assign nq[4+l]=nq[l];assign ri[4+l]=ni[2+l];assign rq[4+l]=nq[2+l];
 end
 reg signed [31:0] ii[0:5],qq[0:5],qi[0:5],iq[0:5];reg [31:0] sqi[0:3],sqq[0:3];
 reg v1,v2,last_lane1;reg [5:0] use1,use2;reg [3:0] keep1,keep2;
 reg [5:0] sh1,sv1,sh2,sv2;reg [31:0] center1,center2;
 reg signed [32:0] re2[0:5],im2[0:5];reg [31:0] power2[0:3],prior1[0:1],prior2[0:3];
 reg signed [47:0] sum_re[0:15],sum_im[0:15];reg [31:0] sum_center[0:15];reg [14:0] sum_count[0:15];reg [45:0] sum_en[0:15],sum_ep[0:15];
 assign bin_real=sum_re[query_bin];assign bin_imag=sum_im[query_bin];assign bin_center_twice=sum_center[query_bin];assign bin_count=sum_count[query_bin];assign bin_energy_now=sum_en[query_bin];assign bin_energy_prev=sum_ep[query_bin];
 assign job_ready=!active&&!result_valid&&!rst&&!abort;assign sample_ready=active&&!closing&&!rst&&!abort;
 wire take=sample_valid&&sample_ready;
 wire bad=lane_count==0||lane_count>2||sample_index!=expected||expected+lane_count>total||sample_last!=(expected+lane_count==total);
 wire [3:0] use_body=body_keep&{lane_count==2,1'b1,lane_count==2,1'b1};
 integer p,l,b;reg c0,c1;reg [5:0] bins_for_pol;
 always @(posedge clk)begin
  if(rst||abort)begin
   active<=0;closing<=0;expected<=0;total<=0;result_valid<=0;error<=0;v1<=0;v2<=0;previous_valid<=0;
   hv_real<=0;hv_imag<=0;hv_energy_h<=0;hv_energy_v<=0;hv_count<=0;body_energy_h<=0;body_energy_v<=0;body_count_h<=0;body_count_v<=0;
   for(b=0;b<16;b=b+1)begin sum_re[b]<=0;sum_im[b]<=0;sum_center[b]<=0;sum_count[b]<=0;sum_en[b]<=0;sum_ep[b]<=0;end
  end else begin
   error<=0;v1<=take&&!bad;v2<=v1;
   if(result_valid&&result_release)result_valid<=0;
   if(take)begin
    if(bad)begin active<=0;closing<=0;v1<=0;v2<=0;error<=1;end
    else begin
     expected<=expected+lane_count;if(sample_last)closing<=1;
     keep1<=use_body;last_lane1<=lane_count==2;sh1<=segment_h;sv1<=segment_v;center1<={16'd0,sample_index,1'b0}-32'd1;
     for(p=0;p<2;p=p+1)begin
      use1[2*p]<=use_body[2*p]&&previous_valid[p];use1[2*p+1]<=use_body[2*p]&&use_body[2*p+1];
      previous_valid[p]<=use_body[2*p+(lane_count==2)];previous_i[p]<=ni[2*p+(lane_count==2)];previous_q[p]<=nq[2*p+(lane_count==2)];
      prior1[p]<=v1?(sqi[2*p+last_lane1]+sqq[2*p+last_lane1]):previous_power[p];
     end
     use1[4]<=use_body[0]&&use_body[2];use1[5]<=use_body[1]&&use_body[3];
     for(l=0;l<6;l=l+1)begin ii[l]<=ni[l]*ri[l];qq[l]<=nq[l]*rq[l];qi[l]<=nq[l]*ri[l];iq[l]<=ni[l]*rq[l];end
     for(l=0;l<4;l=l+1)begin sqi[l]<=ni[l]*ni[l];sqq[l]<=nq[l]*nq[l];end
    end
   end
   if(v1)begin
    use2<=use1;keep2<=keep1;sh2<=sh1;sv2<=sv1;center2<=center1;
    for(l=0;l<6;l=l+1)begin re2[l]<=$signed({ii[l][31],ii[l]})+$signed({qq[l][31],qq[l]});im2[l]<=$signed({qi[l][31],qi[l]})-$signed({iq[l][31],iq[l]});end
    for(l=0;l<4;l=l+1)power2[l]<=sqi[l]+sqq[l];
    for(p=0;p<2;p=p+1)begin prior2[2*p]<=prior1[p];prior2[2*p+1]<=sqi[2*p]+sqq[2*p];previous_power[p]<=sqi[2*p+last_lane1]+sqq[2*p+last_lane1];end
   end
   if(v2)begin
    body_energy_h<=body_energy_h+(keep2[0]?power2[0]:32'd0)+(keep2[1]?power2[1]:32'd0);
    body_energy_v<=body_energy_v+(keep2[2]?power2[2]:32'd0)+(keep2[3]?power2[3]:32'd0);
    body_count_h<=body_count_h+{14'd0,keep2[0]}+{14'd0,keep2[1]};body_count_v<=body_count_v+{14'd0,keep2[2]}+{14'd0,keep2[3]};
    for(b=0;b<16;b=b+1)begin
     p=b/8;bins_for_pol=p==0?sh2:sv2;c0=use2[2*p]&&(bins_for_pol[2:0]==b%8);c1=use2[2*p+1]&&(bins_for_pol[5:3]==b%8);
     sum_re[b]<=sum_re[b]+(c0?re2[2*p]:33'sd0)+(c1?re2[2*p+1]:33'sd0);
     sum_im[b]<=sum_im[b]+(c0?im2[2*p]:33'sd0)+(c1?im2[2*p+1]:33'sd0);
     sum_center[b]<=sum_center[b]+(c0?center2:32'd0)+(c1?center2+32'd2:32'd0);
     sum_count[b]<=sum_count[b]+{14'd0,c0}+{14'd0,c1};
     sum_en[b]<=sum_en[b]+(c0?power2[2*p]:32'd0)+(c1?power2[2*p+1]:32'd0);
     sum_ep[b]<=sum_ep[b]+(c0?prior2[2*p]:32'd0)+(c1?prior2[2*p+1]:32'd0);
    end
    hv_real<=hv_real+(use2[4]?re2[4]:33'sd0)+(use2[5]?re2[5]:33'sd0);
    hv_imag<=hv_imag+(use2[4]?im2[4]:33'sd0)+(use2[5]?im2[5]:33'sd0);
    hv_energy_h<=hv_energy_h+(use2[4]?power2[0]:32'd0)+(use2[5]?power2[1]:32'd0);
    hv_energy_v<=hv_energy_v+(use2[4]?power2[2]:32'd0)+(use2[5]?power2[3]:32'd0);
    hv_count<=hv_count+{14'd0,use2[4]}+{14'd0,use2[5]};
   end
   if(active&&closing&&!v1&&!v2)begin result_valid<=1;active<=0;closing<=0;end
   if(job_valid&&job_ready)begin
    if(job_count==0||job_count>16384)error<=1;
    else begin
     active<=1;closing<=0;expected<=0;total<=job_count;previous_valid<=0;v1<=0;v2<=0;
     hv_real<=0;hv_imag<=0;hv_energy_h<=0;hv_energy_v<=0;hv_count<=0;body_energy_h<=0;body_energy_v<=0;body_count_h<=0;body_count_v<=0;
     for(b=0;b<16;b=b+1)begin sum_re[b]<=0;sum_im[b]<=0;sum_center[b]<=0;sum_count[b]<=0;sum_en[b]<=0;sum_ep[b]<=0;end
    end
   end
  end
 end
endmodule
