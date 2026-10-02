// Carry-select blocks keep the bit-serial divider at one bit per clock without
// a single256-bit ripple path. All arithmetic is unsigned and exact.
module fine_carry_select #(parameter integer WIDTH=256)(
 input wire [WIDTH-1:0] a,b,input wire carry_in,output wire [WIDTH-1:0] sum,output wire carry_out
);
 localparam N=WIDTH/32;wire [N:0] carry;assign carry[0]=carry_in;assign carry_out=carry[N];
 for(genvar i=0;i<N;i=i+1)begin: block_sum
  wire [32:0] s0={1'b0,a[i*32+:32]}+{1'b0,b[i*32+:32]};
  wire [32:0] s1={1'b0,a[i*32+:32]}+{1'b0,b[i*32+:32]}+33'd1;
  assign sum[i*32+:32]=carry[i]?s1[31:0]:s0[31:0];
  assign carry[i+1]=s0[32]|((&s0[31:0])&&carry[i]);
 end
endmodule

// Exact unsigned256 arithmetic with a pipelined32x32 schoolbook multiplier.
// No leading zero limbs/bits are iterated. Result/overflow/rounding semantics
// match fine_wide_math; this implementation intentionally has different latency.
module fine_fast_math(
 input wire clk,rst,abort,req_valid,output wire req_ready,
 input wire [1:0] operation,input wire round_nearest,input wire [255:0] operand_a,operand_b,
 output reg result_valid,input wire result_ready,output reg [255:0] result,output reg fault
);
 localparam IDLE=0,ADD=1,MUL_INIT=2,MUL=3,MUL_DRAIN=4,MUL_DONE=5,DIV_INIT=6,DIV=7,DIV_FIN=8,ROUND=9,INC=10;
 reg [3:0] state;reg [255:0] a,b,quotient,remainder_reg;reg subtract,rounding;
 reg [511:0] product;reg [63:0] term;reg [3:0] term_shift;reg term_valid;
 reg [2:0] i,j,imax,jmax;reg [8:0] remaining;
 reg [2:0] last_a,last_b;reg [7:0] high_bit;
 always @*begin
  last_a=0;last_b=0;high_bit=0;
  for(integer n=0;n<8;n=n+1)begin if(a[n*32+:32]!=0)last_a=n;if(b[n*32+:32]!=0)last_b=n;end
  for(integer n=0;n<256;n=n+1)if(a[n])high_bit=n;
 end
 wire [255:0] trial={remainder_reg[254:0],quotient[255]};
 wire [255:0] aa=state==ADD?a:(state==DIV?trial:(state==ROUND?remainder_reg<<1:quotient));
 wire [255:0] bb=state==ADD?(subtract?~b:b):(state==INC?256'd0:~b);
 wire cin=state==ADD?subtract:1'b1;wire [255:0] sum;wire cout;
 fine_carry_select addsub(.a(aa),.b(bb),.carry_in(cin),.sum(sum),.carry_out(cout));
 wire take_bit=remainder_reg[255]||cout;
 wire [511:0] shifted_term={448'd0,term}<<(term_shift*32);wire [511:0] product_sum;
 fine_carry_select #(.WIDTH(512)) product_add(.a(product),.b(shifted_term),.carry_in(1'b0),.sum(product_sum),.carry_out());
 assign req_ready=state==IDLE&&!result_valid&&!rst&&!abort;
 always @(posedge clk)begin
  if(rst||abort)begin state<=IDLE;result_valid<=0;result<=0;fault<=0;term_valid<=0;end
  else begin
   if(result_valid&&result_ready)result_valid<=0;
   term_valid<=state==MUL;
   if(term_valid)product<=product_sum;
   case(state)
    IDLE:if(req_valid&&req_ready)begin
     a<=operand_a;b<=operand_b;fault<=0;subtract<=operation[0];rounding<=round_nearest;
     case(operation)
      0,1:state<=ADD;
      2:begin product<=0;state<=MUL_INIT;end
      3:if(operand_b==0)begin result<=0;fault<=1;result_valid<=1;end else state<=DIV_INIT;
     endcase
    end
    ADD:begin result<=sum;fault<=subtract?!cout:cout;result_valid<=1;state<=IDLE;end
    MUL_INIT:begin i<=0;j<=0;imax<=last_a;jmax<=last_b;state<=MUL;end
    MUL:begin
     term<=a[i*32+:32]*b[j*32+:32];term_shift<={1'b0,i}+{1'b0,j};
     if(j==jmax)begin j<=0;if(i==imax)state<=MUL_DRAIN;else i<=i+1'b1;end else j<=j+1'b1;
    end
    MUL_DRAIN:state<=MUL_DONE;
    MUL_DONE:begin result<=product[255:0];fault<=|product[511:256];result_valid<=1;state<=IDLE;end
    DIV_INIT:begin quotient<=a<<(8'd255-high_bit);remainder_reg<=0;remaining<={1'b0,high_bit}+9'd1;state<=DIV;end
    DIV:begin
     quotient<={quotient[254:0],take_bit};remainder_reg<=take_bit?sum:trial;
     remaining<=remaining-1'b1;if(remaining==1)state<=DIV_FIN;
    end
    DIV_FIN:if(rounding)state<=ROUND;else begin result<=quotient;result_valid<=1;state<=IDLE;end
    ROUND:if(take_bit)state<=INC;else begin result<=quotient;result_valid<=1;state<=IDLE;end
    INC:begin result<=sum;fault<=cout;result_valid<=1;state<=IDLE;end
   endcase
  end
 end
endmodule
