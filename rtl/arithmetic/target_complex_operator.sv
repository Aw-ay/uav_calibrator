// Row-major complex H/V matrix, then one external Doppler phasor.
// Two registered stages: matrix sum, then phase multiply/quantize.
// No phase accumulator: caller supplies exactly one task-policy-approved phase.
module target_complex_operator(
 input wire clk,rst,in_valid,model_valid,
 input wire [63:0] in_hv,
 input wire [143:0] matrix,
 input wire signed [17:0] phase_i,phase_q,
 output reg out_valid,out_model_valid,
 output reg [63:0] out_hv,output reg saturated);
 wire signed [15:0] hi=in_hv[15:0],hq=in_hv[31:16],vi=in_hv[47:32],vq=in_hv[63:48];
 reg stage_valid,stage_model_valid;
 reg signed [17:0] stage_phase_i,stage_phase_q;
 always @(posedge clk) begin
   if(rst) begin stage_valid<=0;stage_model_valid<=0;stage_phase_i<=0;stage_phase_q<=0;end
   else begin stage_valid<=in_valid;stage_model_valid<=in_valid&&model_valid;stage_phase_i<=phase_i;stage_phase_q<=phase_q;end
 end
 wire [63:0] quantized;wire [3:0] clips;
 genvar row;
 generate for(row=0;row<2;row=row+1) begin : rows
   wire signed [17:0] a=matrix[row*72+:18],b=matrix[row*72+18+:18],c=matrix[row*72+36+:18],d=matrix[row*72+54+:18];
   wire signed [33:0] ha=hi*a,hb=hq*b,vc=vi*c,vd=vq*d;
   wire signed [33:0] hab=hi*b,hba=hq*a,vcd=vi*d,vdc=vq*c;
   wire signed [35:0] matrix_i=$signed(ha)-$signed(hb)+$signed(vc)-$signed(vd);
   wire signed [35:0] matrix_q=$signed(hab)+$signed(hba)+$signed(vcd)+$signed(vdc);
   reg signed [35:0] mi,mq;
   always @(posedge clk) begin
     if(rst) begin mi<=0;mq<=0;end
     else begin mi<=matrix_i;mq<=matrix_q;end
   end
   wire signed [53:0] ii=mi*stage_phase_i,qq=mq*stage_phase_q,iq=mi*stage_phase_q,qi=mq*stage_phase_i;
   wire signed [54:0] oi=$signed(ii)-$signed(qq),oq=$signed(iq)+$signed(qi);
   fixed_round_sat #(.IN_W(55),.SHIFT(32)) ri(oi,quantized[row*32+:16],clips[row*2]);
   fixed_round_sat #(.IN_W(55),.SHIFT(32)) rq(oq,quantized[row*32+16+:16],clips[row*2+1]);
 end endgenerate
 always @(posedge clk) begin
   if(rst) begin out_valid<=0;out_model_valid<=0;out_hv<=0;saturated<=0;end
   else begin
     out_valid<=stage_valid;out_model_valid<=stage_model_valid;
     out_hv<=stage_model_valid ? quantized : 64'd0;
     saturated<=stage_model_valid&&(|clips);
   end
 end
endmodule
