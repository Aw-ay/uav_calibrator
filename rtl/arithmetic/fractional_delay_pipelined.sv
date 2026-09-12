// Fully registered product + balanced binary sum tree + convergent quantizer.
// For63taps:8register stages, one sample/clock; all arithmetic remains full precision.
module fractional_delay_pipelined #(parameter integer TAPS=63)(
 input wire clk,rst,clear,in_valid,coeff_valid,
 input wire signed [15:0] in_i,in_q,
 input wire [TAPS*18-1:0] coefficients,
 output reg out_valid,out_coeff_valid,
 output reg signed [15:0] out_i,out_q,output reg saturated);
 localparam LEVELS=$clog2(TAPS),LEAVES=1<<LEVELS,ACC_W=34+LEVELS;
 reg signed [15:0] history_i[0:TAPS-1],history_q[0:TAPS-1];
 reg signed [ACC_W-1:0] tree_i[0:LEVELS][0:LEAVES-1],tree_q[0:LEVELS][0:LEAVES-1];
 reg [LEVELS:0] valid_pipe,qualified_pipe;
 integer j;
 genvar leaf,level,node;
 generate for(leaf=0;leaf<LEAVES;leaf=leaf+1)begin : products
   if(leaf<TAPS)begin : real_tap
     wire signed [17:0] c=coefficients[leaf*18+:18];
     wire signed [15:0] xi,xq;
     if(leaf==0)begin assign xi=in_i;assign xq=in_q;end
     else begin assign xi=history_i[leaf-1];assign xq=history_q[leaf-1];end
     wire signed [33:0] pi=xi*c,pq=xq*c;
     always @(posedge clk)begin
       if(rst||clear)begin tree_i[0][leaf]<=0;tree_q[0][leaf]<=0;end
       else begin tree_i[0][leaf]<=$signed(pi);tree_q[0][leaf]<=$signed(pq);end
     end
   end else begin : padding
     always @(posedge clk)begin tree_i[0][leaf]<=0;tree_q[0][leaf]<=0;end
   end
 end
 for(level=1;level<=LEVELS;level=level+1)begin : levels
   for(node=0;node<(LEAVES>>level);node=node+1)begin : sums
     // Resource contract reserves DSPs for126real products per complex channel.
     (* use_dsp="no" *) wire signed [ACC_W-1:0] sum_i=tree_i[level-1][node*2]+tree_i[level-1][node*2+1];
     (* use_dsp="no" *) wire signed [ACC_W-1:0] sum_q=tree_q[level-1][node*2]+tree_q[level-1][node*2+1];
     always @(posedge clk)begin
       if(rst||clear)begin tree_i[level][node]<=0;tree_q[level][node]<=0;end
       else begin
         tree_i[level][node]<=sum_i;
         tree_q[level][node]<=sum_q;
       end
     end
   end
 end endgenerate
 wire signed [15:0] yi,yq;wire si,sq;
 fixed_round_sat #(.IN_W(ACC_W)) ri(tree_i[LEVELS][0],yi,si),rq(tree_q[LEVELS][0],yq,sq);
 always @(posedge clk)begin
   if(rst||clear)begin
     for(j=0;j<TAPS;j=j+1)begin history_i[j]<=0;history_q[j]<=0;end
     valid_pipe<=0;qualified_pipe<=0;out_valid<=0;out_coeff_valid<=0;out_i<=0;out_q<=0;saturated<=0;
   end else begin
     valid_pipe<=(valid_pipe<<1)|in_valid;
     qualified_pipe<=(qualified_pipe<<1)|(in_valid&&coeff_valid);
     out_valid<=valid_pipe[LEVELS];out_coeff_valid<=qualified_pipe[LEVELS];
     out_i<=qualified_pipe[LEVELS] ? yi : 16'sd0;
     out_q<=qualified_pipe[LEVELS] ? yq : 16'sd0;
     saturated<=qualified_pipe[LEVELS]&&(si||sq);
     if(in_valid)begin
       history_i[0]<=in_i;history_q[0]<=in_q;
       for(j=1;j<TAPS;j=j+1)begin history_i[j]<=history_i[j-1];history_q[j]<=history_q[j-1];end
     end
   end
 end
 initial if(TAPS<1)$fatal(1,"TAPS must be positive");
endmodule
