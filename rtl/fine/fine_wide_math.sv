// Shared exact unsigned256 arithmetic. Only one 32-bit carry chain per cycle.
// op: 0 add (overflow), 1 subtract (borrow), 2 multiply (overflow), 3 divide
// (zero divisor). Division optionally rounds nearest, exact halves upward.
// A held result owns the unit until consumed. Cold reset/abort cancels all work.
module fine_wide_math(
 input wire clk,rst,abort,req_valid,output wire req_ready,
 input wire [1:0] operation,input wire round_nearest,input wire [255:0] operand_a,operand_b,
 output reg result_valid,input wire result_ready,output reg [255:0] result,output reg fault
);
 localparam IDLE=0,ADD=1,MUL_BIT=2,MUL_ADD=3,MUL_FIN=4,DIV_SHIFT=5,
            DIV_SUB=6,DIV_DECIDE=7,DIV_ROUND=8,ROUND_SUB=9,ROUND_DECIDE=10,INCREMENT=11;
 reg [3:0] state,limb;reg [8:0] remaining;
 reg [255:0] a,b,work,quotient,remainder_reg,trial;
 reg [511:0] product,multiplicand;reg [255:0] multiplier;
 reg carry,subtract,rounding;
 reg [31:0] left_word,right_word;reg [32:0] word_sum;
 always @*begin
  left_word=0;right_word=0;
  case(state)
   ADD:begin left_word=a[limb*32+:32];right_word=subtract?~b[limb*32+:32]:b[limb*32+:32];end
   MUL_ADD:begin left_word=product[limb*32+:32];right_word=multiplicand[limb*32+:32];end
   DIV_SUB,ROUND_SUB:begin left_word=trial[limb*32+:32];right_word=~b[limb*32+:32];end
   INCREMENT:begin left_word=quotient[limb*32+:32];end
   default:begin end
  endcase
  word_sum={1'b0,left_word}+{1'b0,right_word}+carry;
 end
 assign req_ready=state==IDLE&&!result_valid&&!rst&&!abort;
 always @(posedge clk)begin
  if(rst||abort)begin state<=IDLE;result_valid<=0;result<=0;fault<=0;end
  else begin
   if(result_valid&&result_ready)result_valid<=0;
   case(state)
    IDLE:if(req_valid&&req_ready)begin
     a<=operand_a;b<=operand_b;fault<=0;limb<=0;work<=0;
     case(operation)
      0,1:begin state<=ADD;subtract<=operation[0];carry<=operation[0];end
      2:begin state<=MUL_BIT;product<=0;multiplicand<={256'd0,operand_a};multiplier<=operand_b;remaining<=256;end
      3:begin
       if(operand_b==0)begin result<=0;fault<=1;result_valid<=1;end
       else begin state<=DIV_SHIFT;quotient<=operand_a;remainder_reg<=0;remaining<=256;rounding<=round_nearest;end
      end
     endcase
    end
    ADD:begin
     work[limb*32+:32]<=word_sum[31:0];carry<=word_sum[32];
     if(limb==7)begin
      result<={word_sum[31:0],work[223:0]};fault<=subtract?!word_sum[32]:word_sum[32];result_valid<=1;state<=IDLE;
     end else limb<=limb+1'b1;
    end
    MUL_BIT:begin
     if(remaining==0)state<=MUL_FIN;
     else if(multiplier[0])begin state<=MUL_ADD;limb<=0;carry<=0;end
     else begin multiplier<=multiplier>>1;multiplicand<=multiplicand<<1;remaining<=remaining-1'b1;end
    end
    MUL_ADD:begin
     product[limb*32+:32]<=word_sum[31:0];carry<=word_sum[32];
     if(limb==15)begin
      multiplier<=multiplier>>1;multiplicand<=multiplicand<<1;remaining<=remaining-1'b1;state<=MUL_BIT;
     end else limb<=limb+1'b1;
    end
    MUL_FIN:begin result<=product[255:0];fault<=|product[511:256];result_valid<=1;state<=IDLE;end
    DIV_SHIFT:begin
     trial<={remainder_reg[254:0],quotient[255]};quotient<=quotient<<1;
     // remainder<denominator and numerator is256 bits; the trial can have a
     // 257th bit. Preserve it as the initial borrow-extension decision below.
     subtract<=remainder_reg[255];carry<=1;limb<=0;state<=DIV_SUB;
    end
    DIV_SUB:begin
     work[limb*32+:32]<=word_sum[31:0];carry<=word_sum[32];
     if(limb==7)state<=DIV_DECIDE;else limb<=limb+1'b1;
    end
    DIV_DECIDE:begin
     if(carry||subtract)begin remainder_reg<=work;quotient[0]<=1;end
     else remainder_reg<=trial;
     remaining<=remaining-1'b1;
     if(remaining==1)state<=DIV_ROUND;else state<=DIV_SHIFT;
    end
    DIV_ROUND:begin
     if(!rounding)begin result<=quotient;result_valid<=1;state<=IDLE;end
     else begin
      trial<=remainder_reg<<1;subtract<=remainder_reg[255];limb<=0;carry<=1;state<=ROUND_SUB;
     end
    end
    ROUND_SUB:begin
     carry<=word_sum[32];
     if(limb==7)state<=ROUND_DECIDE;else limb<=limb+1'b1;
    end
    ROUND_DECIDE:begin
     if(carry||subtract)begin limb<=0;carry<=1;state<=INCREMENT;end
     else begin result<=quotient;result_valid<=1;state<=IDLE;end
    end
    INCREMENT:begin
     quotient[limb*32+:32]<=word_sum[31:0];carry<=word_sum[32];
     if(limb==7)begin result<={word_sum[31:0],quotient[223:0]};fault<=word_sum[32];result_valid<=1;state<=IDLE;end
     else limb<=limb+1'b1;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
