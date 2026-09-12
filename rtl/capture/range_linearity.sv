// Logical energy-consistency evaluator. Input windows must be identical and
// overlap_valid must exclude clipping, low SNR and invalid calibration domains.
// Pair agreement cannot prove common-front-end linearity or phase fidelity.
// Normalization is unsigned POWER scale Q16, never amplitude gain or dB.
module range_linearity(
 input wire [275:0] energy,
 input wire [191:0] power_scale_q16,
 input wire [5:0] calibration_valid,overlap_valid,
 input wire tolerance_valid,context_valid,common_known,common_pass,
 input wire [15:0] tolerance_q16,
 output wire [5:0] pair_known,pair_pass,linearity_known,linearity_pass
);
 wire [77:0] normalized[0:5];
 wire [5:0] eligible;
 genvar c,p;
 generate for(c=0;c<6;c=c+1)begin: channel
  wire [45:0] e=energy[c*46+:46];
  wire [31:0] scale=power_scale_q16[c*32+:32];
  assign normalized[c]={32'd0,e}*{46'd0,scale};
  assign eligible[c]=context_valid&&tolerance_valid&&calibration_valid[c]&&overlap_valid[c]&&e!=0&&scale!=0;
 end
 for(p=0;p<6;p=p+1)begin: pair_check
  // Pair order H01,H12,H02,V01,V12,V02.
  localparam A=(p/3)*3+((p%3)==1?1:0);
  localparam B=(p/3)*3+((p%3)==0?1:2);
  wire [77:0] a=normalized[A],b=normalized[B];
  wire [77:0] largest=a>=b?a:b;
  wire [77:0] difference=a>=b?a-b:b-a;
  wire [93:0] budget={16'd0,largest}*{78'd0,tolerance_q16};
  assign pair_known[p]=eligible[A]&&eligible[B];
  assign pair_pass[p]=pair_known[p]&&{difference,16'd0}<=budget;
 end
 for(c=0;c<6;c=c+1)begin: decision
  localparam P=(c/3)*3+((c%3)==2?1:0);
  localparam Q=(c/3)*3+((c%3)==1?1:2);
  wire relative_known=pair_known[P]||pair_known[Q];
  wire relative_pass=(!pair_known[P]||pair_pass[P])&&(!pair_known[Q]||pair_pass[Q]);
  assign linearity_known[c]=common_known&&relative_known;
  assign linearity_pass[c]=linearity_known[c]&&common_pass&&relative_pass;
 end endgenerate
endmodule
