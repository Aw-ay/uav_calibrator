// Exact sufficient-statistic FINALIZE, H then V then cross-polarization.
// Inputs are frozen on acceptance. No sample RAM access, FFT or per-sample atan2.
module fine_finalize #(parameter integer FAST_MATH=0)(
 input wire clk,rst,abort,job_valid,output wire job_ready,
 input wire [3759:0] bin_data,input wire [91:0] body_energy,input wire [29:0] body_count,
 input wire signed [47:0] hv_real,hv_imag,input wire [45:0] hv_energy_h,hv_energy_v,input wire [14:0] hv_count,
 input wire [63:0] noise,input wire [1:0] timing_valid,
 output reg result_valid,input wire result_ready,
 output reg [63:0] mean_power,snr_q16,frequency_hz,output reg [127:0] chirp_hz_per_s,
 output reg [31:0] hv_phase_q31,output reg [1:0] snr_saturated,output reg [2:0] valid_mask,output reg [23:0] quality
);
 reg active;reg [7:0] state,return_state;reg [1:0] pol,math_phase;reg [2:0] bin_index;
 reg [3759:0] saved_bins;reg [91:0] energies;reg [29:0] counts;reg [202:0] cross_data;
 reg [63:0] noises;reg [1:0] edges;
 wire [234:0] row=saved_bins[({pol[0],bin_index})*235+:235];
 wire signed [47:0] re=pol==2?cross_data[47:0]:row[47:0],im=pol==2?cross_data[95:48]:row[95:48];
 wire [47:0] ar=re[47]?-re:re,ai=im[47]?-im:im;
 wire [45:0] en=pol==2?cross_data[141:96]:row[188:143],ep=pol==2?cross_data[187:142]:row[234:189];
 wire [14:0] samples=pol==2?cross_data[202:188]:counts[pol[0]*15+:15];
 wire [31:0] n0=noises[pol[0]*32+:32];
 reg [255:0] tmp[0:5];reg ti,ts;
 reg [31:0] center,phase_value,previous_phase;reg previous_phase_valid,phase_bad;
 reg [3:0] populated;reg [47:0] sx;reg signed [47:0] sy;
 reg [95:0] sxx;reg signed [95:0] sxy;
 wire [47:0] asy=sy[47]?-sy:sy;wire [95:0] asxy=sxy[95]?-sxy:sxy;
 wire signed [32:0] phase_delta=$signed({phase_value[31],phase_value})-$signed({previous_phase[31],previous_phase});
 wire [31:0] abs_phase=phase_value[31]?-phase_value:phase_value;
 reg [1:0] math_op;reg [255:0] arg_a,arg_b;reg sign_a,sign_b,rounding;
 wire math_ready,math_valid,math_fault,math_negative;wire [255:0] math_magnitude;
 reg [255:0] mr;reg mn;
 fine_signed_math #(.FAST_MATH(FAST_MATH)) arithmetic(.clk(clk),.rst(rst),.abort(abort),.req_valid(math_phase==1),.req_ready(math_ready),
  .operation(math_op),.round_nearest(rounding),.magnitude_a(arg_a),.magnitude_b(arg_b),.negative_a(sign_a),.negative_b(sign_b),
  .result_valid(math_valid),.result_ready(math_phase==2),.magnitude(math_magnitude),.negative(math_negative),.fault(math_fault));
 wire phase_ready,phase_valid,phase_zero;wire signed [31:0] phase_result;
 fine_cordic cordic(.clk(clk),.rst(rst||abort),.request_valid(active&&state==50&&math_phase==0),.request_ready(phase_ready),
  .x_in(re),.y_in(im),.result_valid(phase_valid),.result_ready(state==51),.phase_q31(phase_result),.zero_vector(phase_zero),.busy());
 assign job_ready=!active&&!result_valid&&!rst&&!abort;
 task automatic calc(input [1:0] op,input [255:0] a,b,input sa,sb,rnd,input [7:0] next_state);begin
  math_op<=op;arg_a<=a;arg_b<=b;sign_a<=sa;sign_b<=sb;rounding<=rnd;return_state<=next_state;math_phase<=1;
 end endtask
 task automatic invalid(input [7:0] flags);begin
  quality[pol*8+:8]<=flags;valid_mask[pol]<=0;
  if(pol<2)begin frequency_hz[pol*32+:32]<=0;chirp_hz_per_s[pol*64+:64]<=0;end
  else hv_phase_q31<=0;
  state<=200;
 end endtask
 always @(posedge clk)begin
  if(rst||abort)begin
   active<=0;state<=0;math_phase<=0;result_valid<=0;mean_power<=0;snr_q16<=0;frequency_hz<=0;chirp_hz_per_s<=0;
   hv_phase_q31<=0;snr_saturated<=0;valid_mask<=0;quality<=0;
  end else begin
   if(result_valid&&result_ready)result_valid<=0;
   if(job_valid&&job_ready)begin
    saved_bins<=bin_data;energies<=body_energy;counts<=body_count;cross_data<={hv_count,hv_energy_v,hv_energy_h,hv_imag,hv_real};
    noises<=noise;edges<=timing_valid;active<=1;pol<=0;state<=1;math_phase<=0;
    mean_power<=0;snr_q16<=0;frequency_hz<=0;chirp_hz_per_s<=0;hv_phase_q31<=0;snr_saturated<=0;valid_mask<=0;quality<=0;
   end else if(active)begin
    if(math_phase==1)begin if(math_ready)math_phase<=2;end
    else if(math_phase==2)begin
     if(math_valid)begin
      math_phase<=0;mr<=math_magnitude;mn<=math_negative;
      if(math_fault)invalid(8);else state<=return_state;
     end
    end else case(state)
     1:begin
      sx<=0;sy<=0;sxx<=0;sxy<=0;populated<=0;previous_phase_valid<=0;phase_bad<=0;bin_index<=0;
      if(pol==2)begin
       if(edges!=3)invalid(16);else if(samples<9)invalid(1);else state<=30;
      end else if(!edges[pol])invalid(16);
      else if(samples==0)invalid(1);
      else calc(3,energies[pol*46+:46],samples,0,0,0,10);
     end
     10:begin mean_power[pol*32+:32]<=mr[31:0];state<=11;end
     11:begin
      if(n0==0)begin snr_q16[pol*32+:32]<=32'hffffffff;snr_saturated[pol]<=1;state<=14;end
      else if(mean_power[pol*32+:32]<=n0)state<=14;
      else calc(1,mean_power[pol*32+:32],n0,0,0,0,12);
     end
     12:calc(3,mr<<16,n0,0,0,0,13);
     13:begin snr_q16[pol*32+:32]<=(|mr[255:32])?32'hffffffff:mr[31:0];snr_saturated[pol]<=|mr[255:32];state<=14;end
     14:if(samples<9)invalid(1);else state<=20;
     20:if(row[142:128]==0)state<=80;else state<=30;
     30:if(re==0&&im==0)invalid(4);else calc(2,ar,ar,0,0,0,31);
     31:begin tmp[3]<=mr;calc(2,ai,ai,0,0,0,32);end
     32:calc(0,tmp[3],mr,0,0,0,33);
     33:begin tmp[3]<=mr<<2;calc(2,en,ep,0,0,0,34);end
     34:calc(1,tmp[3],mr,0,0,0,35);
     35:if(mn)invalid(32);else if(pol==2)state<=50;else calc(3,{209'd0,row[127:96],15'd0},row[142:128],0,0,1,40);
     40:begin center<=mr[31:0];state<=50;end
     50:if(phase_ready)state<=51;
     51:if(phase_valid)begin
      if(phase_zero)invalid(4);
      else if(pol==2)begin hv_phase_q31<=phase_result;valid_mask[2]<=1;state<=200;end
      else begin phase_value<=phase_result;state<=52;end
     end
     52:begin
      if(({32'd0,abs_phase}*64'd100)>64'd105226698752 ||
        (previous_phase_valid&&(phase_delta>33'sd536870912||phase_delta< -33'sd536870912)))phase_bad<=1;
      calc(2,center,center,0,0,0,60);
     end
     60:begin
      sxx<=sxx+mr[95:0];calc(2,center,abs_phase,0,phase_value[31],0,61);
     end
     61:begin
      sxy<=sxy+(mn?-$signed(mr[95:0]):$signed(mr[95:0]));sx<=sx+center;sy<=sy+$signed(phase_value);
      populated<=populated+1'b1;previous_phase<=phase_value;previous_phase_valid<=1;state<=80;
     end
     80:if(bin_index==7)state<=100;else begin bin_index<=bin_index+1'b1;state<=20;end
     100:if(populated<2)invalid(2);else if(phase_bad)invalid(8);else calc(2,populated,sxx,0,0,0,101);
     101:begin tmp[3]<=mr;calc(2,sx,sx,0,0,0,102);end
     102:calc(1,tmp[3],mr,0,0,0,103);
     103:if(mn||mr==0)invalid(2);else begin tmp[0]<=mr;calc(2,asy,sxx,sy[47],0,0,104);end
     104:begin tmp[3]<=mr;ti<=mn;calc(2,sx,asxy,0,sxy[95],0,105);end
     105:calc(1,tmp[3],mr,ti,mn,0,106);
     106:begin tmp[1]<=mr;ti<=mn;calc(2,populated,asxy,0,sxy[95],0,107);end
     107:begin tmp[3]<=mr;ts<=mn;calc(2,sx,asy,0,sy[47],0,108);end
     108:calc(1,tmp[3],mr,ts,mn,0,109);
     109:begin tmp[2]<=mr;ts<=mn;calc(2,tmp[1],256'd125000000,ti,0,0,110);end
     110:calc(3,mr,tmp[0]<<31,mn,0,1,111);
     111:begin
      if((|mr[255:32])||mr[31:0]>(mn?32'h80000000:32'h7fffffff))invalid(8);
      else begin frequency_hz[pol*32+:32]<=mn?-mr[31:0]:mr[31:0];calc(2,tmp[2],256'd15625000000000000,ts,0,0,112);end
     end
     112:calc(3,mr,tmp[0]<<15,mn,0,1,113);
     113:begin
      if((|mr[255:64])||mr[63:0]>(mn?64'h8000000000000000:64'h7fffffffffffffff))invalid(8);
      else begin chirp_hz_per_s[pol*64+:64]<=mn?-mr[63:0]:mr[63:0];valid_mask[pol]<=1;state<=200;end
     end
     200:if(pol==2)begin active<=0;result_valid<=1;end else begin pol<=pol+1'b1;state<=1;end
     default:invalid(8);
    endcase
   end
  end
 end
endmodule
