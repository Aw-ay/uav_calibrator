// One local edge candidate: exact pair/OLS roots, variance and weighted fusion.
// Input support is k-3..k+4 clipped by RAW. offset is k within the supplied window.
// This is a shared candidate service, NOT the coarse-window search controller.
module fine_edge_solver #(parameter integer FAST_MATH=0)(
 input wire clk,rst,abort,req_valid,output wire req_ready,
 input wire [255:0] power_window,input wire [3:0] point_count,input wire [2:0] bracket_offset,
 input wire [14:0] bracket_index,input wire [31:0] threshold,noise,input wire rising,
 output reg result_valid,input wire result_ready,output reg edge_valid,output reg [15:0] quality,
 output reg [31:0] index_q16,two_q16,fit_q16,output reg [63:0] variance_two_q32,variance_fit_q32
);
 import fine_edge_program_pkg::*;
 localparam IDLE=0,CHECK=1,SUM=2,MOMENTS=3,COEFF=4,THRESHOLD=5,ROOT=6,
            ROOT_CHECK=7,ZTERM=8,ZDIFF=9,RES_MUL=10,RES_SUB=11,RES_END=12,
            RES_SAVE=13,INIT=14,FETCH=15,READ=16,EXECUTE=17,ISSUE=18,WAIT_MATH=19;
 reg [4:0] state;reg [255:0] powers;reg [3:0] m,j;reg [2:0] off;
 reg [14:0] k;reg [31:0] th,n0;reg rise;
 reg [35:0] sy;reg signed [39:0] sxy;reg signed [7:0] sx;reg [7:0] sxx;
 (* use_dsp="no" *) reg signed [47:0] ma,mb,mc,md,slope,intercept,numerator,threshold_d;
 reg [9:0] denominator;
 (* use_dsp="no" *) reg signed [63:0] za,zb,z,res_dp,res_sx,res_mid,residual;
 wire [31:0] current_power=powers[j*32+:32];
 wire signed [4:0] x=$signed({1'b0,j})-$signed({2'b00,off});
 wire signed [9:0] x_squared=x*x;
 wire signed [15:0] sx_squared=sx*sx;
 wire [31:0] p0=powers[off*32+:32];
 wire [3:0] off_next={1'b0,off}+4'd1;
 wire [31:0] p1=powers[off_next*32+:32];
 wire [31:0] delta_abs=rise?(p1-p0):(p0-p1);
 wire [31:0] offset_abs=rise?(th-p0):(p0-th);
 wire [31:0] signal_power=th>n0?th-n0:32'd0;
 wire [63:0] residual_abs=residual[63]?-residual:residual;
 wire [63:0] z_abs=z[63]?-z:z;
 wire [47:0] abs_slope=slope[47]?-slope:slope,abs_num=numerator[47]?-numerator:numerator;
 reg [255:0] r[0:31];reg [6:0] pc;reg [18:0] inst;
 wire [3:0] op=inst[18:15];wire [4:0] dst=inst[14:10],src_a=inst[9:5],src_b=inst[4:0];
 reg [255:0] argument_a,argument_b;reg last_borrow;
 wire math_req_ready,math_valid,math_fault;wire [255:0] math_result;
 generate if(FAST_MATH)begin: fast_arithmetic
  fine_fast_math math(.clk(clk),.rst(rst),.abort(abort),.req_valid(state==ISSUE),.req_ready(math_req_ready),
   .operation(op[1:0]),.round_nearest(1'b1),.operand_a(argument_a),.operand_b(argument_b),
   .result_valid(math_valid),.result_ready(state==WAIT_MATH),.result(math_result),.fault(math_fault));
 end else begin: serial_arithmetic
 fine_wide_math math(.clk(clk),.rst(rst),.abort(abort),.req_valid(state==ISSUE),.req_ready(math_req_ready),
  .operation(op[1:0]),.round_nearest(1'b1),.operand_a(argument_a),.operand_b(argument_b),
  .result_valid(math_valid),.result_ready(state==WAIT_MATH),.result(math_result),.fault(math_fault));
 end endgenerate
 assign req_ready=state==IDLE&&!result_valid&&!rst&&!abort;
 task automatic fail(input [15:0] reason);begin quality<=reason;edge_valid<=0;result_valid<=1;state<=IDLE;end endtask
 integer t;
 always @(posedge clk)begin
  if(rst||abort)begin
   state<=IDLE;result_valid<=0;edge_valid<=0;quality<=0;
   index_q16<=0;two_q16<=0;fit_q16<=0;variance_two_q32<=0;variance_fit_q32<=0;
  end else begin
   if(result_valid&&result_ready)result_valid<=0;
   case(state)
    IDLE:if(req_valid&&req_ready)begin
     powers<=power_window;m<=point_count;off<=bracket_offset;k<=bracket_index;th<=threshold;n0<=noise;rise<=rising;
     sy<=0;sxy<=0;sx<=0;sxx<=0;j<=0;quality<=0;edge_valid<=0;
     index_q16<=0;two_q16<=0;fit_q16<=0;variance_two_q32<=0;variance_fit_q32<=0;
     for(t=0;t<32;t=t+1)r[t]<=0;
     state<=CHECK;
    end
    CHECK:begin
     if(m<2||m>8||off>3||off_next>=m||m>off+5||k<off||k>=16383)fail(64);
     else if(n0>32'h80000000)fail(128);
     else if(!(rise?(p0<th&&th<=p1):(p0>=th&&th>p1)))fail(rise?16'd2:16'd4);
     else if(m<4)fail(64);
     else state<=SUM;
    end
    SUM:begin
     if(current_power>32'h80000000)fail(128);
     else begin
      sy<=sy+current_power;sxy<=sxy+$signed({1'b0,current_power})*x;sx<=sx+x;sxx<=sxx+x_squared[7:0];
      if(j==m-1'b1)state<=MOMENTS;else j<=j+1'b1;
     end
    end
    MOMENTS:begin
     ma<=$signed({1'b0,m})*sxy;mb<=sx*$signed({1'b0,sy});
     mc<=$signed({1'b0,sxx})*$signed({1'b0,sy});md<=sx*sxy;
     denominator<=m*sxx-sx_squared[9:0];state<=COEFF;
    end
    COEFF:begin slope<=ma-mb;intercept<=mc-md;state<=THRESHOLD;end
    THRESHOLD:begin threshold_d<=$signed({1'b0,th})*$signed({1'b0,denominator});state<=ROOT;end
    ROOT:begin numerator<=threshold_d-intercept;state<=ROOT_CHECK;end
    ROOT_CHECK:begin
     if(slope==0||((!slope[47])!=rise))fail(8);
     else if((numerator!=0&&numerator[47]!=slope[47])||abs_num>abs_slope)fail(96);
     else state<=ZTERM;
    end
    ZTERM:begin za<=$signed({1'b0,m})*numerator;zb<=slope*sx;state<=ZDIFF;end
    ZDIFF:begin z<=za-zb;j<=0;state<=RES_MUL;end
    RES_MUL:begin
     res_dp<=$signed({1'b0,current_power})*$signed({1'b0,denominator});res_sx<=slope*x;state<=RES_SUB;
    end
    RES_SUB:begin res_mid<=res_dp-intercept;state<=RES_END;end
    RES_END:begin residual<=res_mid-res_sx;state<=RES_SAVE;end
    RES_SAVE:begin
     r[11+j]<=residual_abs;
     if(j==m-1'b1)state<=INIT;else begin j<=j+1'b1;state<=RES_MUL;end
    end
    INIT:begin
     r[0]<=1;r[1]<={225'd0,k,16'd0};r[2]<=delta_abs;r[3]<=offset_abs;
     r[4]<=abs_slope;r[5]<=abs_num;r[6]<=denominator;r[7]<=m;r[8]<=z_abs;
     r[9]<=n0;r[10]<=signal_power;r[19]<=2;pc<=0;state<=FETCH;
    end
    FETCH:begin inst<=edge_instruction(pc);state<=READ;end
    READ:begin argument_a<=r[src_a];argument_b<=r[src_b];state<=EXECUTE;end
    EXECUTE:begin
     if(op<=3)state<=ISSUE;
     else case(op)
      4:if(|argument_a[255:240])fail(256);else begin r[dst]<=argument_a<<16;pc<=pc+1'b1;state<=FETCH;end
      5:if(|argument_a[255:224])fail(256);else begin r[dst]<=argument_a<<32;pc<=pc+1'b1;state<=FETCH;end
      6:begin r[dst]<=argument_a==0?256'd1:argument_a;pc<=pc+1'b1;state<=FETCH;end
      7:if(|argument_a[255:64])fail(256);else begin r[dst]<=argument_a==0?256'd1:argument_a;pc<=pc+1'b1;state<=FETCH;end
      8:begin r[25]<=last_borrow?r[22]:r[23];r[26]<=last_borrow?r[0]:r[24];pc<=pc+1'b1;state<=FETCH;end
      9:begin
       if((|r[29][255:32])||(|r[30][255:32])||(|r[31][255:32]))fail(256);
       else begin
        two_q16<=r[29][31:0];fit_q16<=r[30][31:0];index_q16<=r[31][31:0];
        variance_two_q32<=r[27][63:0];variance_fit_q32<=r[28][63:0];edge_valid<=1;result_valid<=1;state<=IDLE;
       end
      end
      default:fail(256);
     endcase
    end
    ISSUE:if(math_req_ready)state<=WAIT_MATH;
    WAIT_MATH:if(math_valid)begin
     if(math_fault&&!(op==1&&pc==EDGE_COMPARE_PC))fail(256);
     else begin r[dst]<=math_result;last_borrow<=math_fault;pc<=pc+1'b1;state<=FETCH;end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
