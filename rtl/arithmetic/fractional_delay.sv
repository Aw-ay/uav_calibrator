// Programmable causal real-coefficient FIR for both components.
// Arithmetic engine, NOT an approved +/-50MHz fractional-delay filter profile.
// Coefficient table must be held stable for a record; clear history before switching.
module fractional_delay #(parameter integer TAPS=4)(
 input wire clk,rst,clear,in_valid,coeff_valid,
 input wire signed [15:0] in_i,in_q,
 input wire [TAPS*18-1:0] coefficients,
 output reg out_valid,out_coeff_valid,
 output reg signed [15:0] out_i,out_q,output reg saturated);
 localparam integer ACC_W=34+$clog2(TAPS);
 reg signed [15:0] history_i[0:TAPS-1],history_q[0:TAPS-1];
 wire signed [33:0] products_i[0:TAPS-1],products_q[0:TAPS-1];
 genvar t;
 generate for(t=0;t<TAPS;t=t+1) begin : taps
   wire signed [17:0] c=coefficients[t*18+:18];
   if(t==0) begin : current_sample
     assign products_i[t]=in_i*c;assign products_q[t]=in_q*c;
   end else begin : old_sample
     assign products_i[t]=history_i[t-1]*c;assign products_q[t]=history_q[t-1]*c;
   end
 end endgenerate
 reg signed [ACC_W-1:0] acc_i,acc_q;integer j;
 always @* begin
   acc_i=0;acc_q=0;
   for(integer k=0;k<TAPS;k=k+1) begin acc_i=acc_i+$signed(products_i[k]);acc_q=acc_q+$signed(products_q[k]);end
 end
 wire signed [15:0] yi,yq;wire si,sq;
 fixed_round_sat #(.IN_W(ACC_W)) ri(acc_i,yi,si),rq(acc_q,yq,sq);
 always @(posedge clk) begin
   if(rst||clear) begin
     for(j=0;j<TAPS;j=j+1) begin history_i[j]<=0;history_q[j]<=0;end
     out_valid<=0;out_coeff_valid<=0;out_i<=0;out_q<=0;saturated<=0;
   end else begin
     out_valid<=in_valid;out_coeff_valid<=in_valid&&coeff_valid;
     out_i<=in_valid&&coeff_valid ? yi : 16'sd0;out_q<=in_valid&&coeff_valid ? yq : 16'sd0;
     saturated<=in_valid&&coeff_valid&&(si||sq);
     if(in_valid) begin
       history_i[0]<=in_i;history_q[0]<=in_q;
       for(j=1;j<TAPS;j=j+1) begin history_i[j]<=history_i[j-1];history_q[j]<=history_q[j-1];end
     end
   end
 end
 initial if(TAPS<1) $fatal(1,"TAPS must be positive");
endmodule
