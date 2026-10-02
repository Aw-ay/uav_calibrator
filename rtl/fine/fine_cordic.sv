// Shared FINALIZE phase kernel. No per-sample atan2 or multiplier.
// Signed48 accumulated complex input; signed turns*2^31 in [-2^30,2^30).
// See contracts/fine_numeric.json and tools/fine_fixed.py for exact arithmetic.
module fine_cordic(
 input wire clk,rst,request_valid,output wire request_ready,
 input wire signed [47:0] x_in,y_in,
 output reg result_valid,input wire result_ready,
 output reg signed [31:0] phase_q31,output reg zero_vector,output wire busy
);
 localparam IDLE=0,PREPARE=1,NORMALIZE=2,ROTATE=3;
 reg [1:0] state;reg signed [49:0] input_x,input_y,quadrant_x,quadrant_y;
 reg signed [47:0] x,y;reg signed [32:0] phase;
 reg signed [6:0] shift;reg [4:0] iteration;
 wire [49:0] abs_x=input_x<0?-input_x:input_x,abs_y=input_y<0?-input_y:input_y;
 wire [49:0] maximum=abs_x>abs_y?abs_x:abs_y;
 reg [5:0] highest;
 always @*begin highest=0;for(integer b=0;b<50;b=b+1)if(maximum[b])highest=b;end
 function automatic signed [32:0] angle(input [4:0] i);
  case(i)
   5'd0:angle=33'sd268435456;
   5'd1:angle=33'sd158466703;
   5'd2:angle=33'sd83729454;
   5'd3:angle=33'sd42502378;
   5'd4:angle=33'sd21333666;
   5'd5:angle=33'sd10677233;
   5'd6:angle=33'sd5339919;
   5'd7:angle=33'sd2670123;
   5'd8:angle=33'sd1335082;
   5'd9:angle=33'sd667543;
   5'd10:angle=33'sd333772;
   5'd11:angle=33'sd166886;
   5'd12:angle=33'sd83443;
   5'd13:angle=33'sd41722;
   5'd14:angle=33'sd20861;
   5'd15:angle=33'sd10430;
   5'd16:angle=33'sd5215;
   5'd17:angle=33'sd2608;
   5'd18:angle=33'sd1304;
   5'd19:angle=33'sd652;
   5'd20:angle=33'sd326;
   5'd21:angle=33'sd163;
   5'd22:angle=33'sd81;
   5'd23:angle=33'sd41;
   5'd24:angle=33'sd20;
   5'd25:angle=33'sd10;
   5'd26:angle=33'sd5;
   5'd27:angle=33'sd3;
   5'd28:angle=33'sd1;
   5'd29:angle=33'sd1;
   5'd30:angle=33'sd0;
   default:angle=0;
  endcase
 endfunction
 reg signed [47:0] next_x,next_y;reg signed [32:0] next_phase,wrapped_phase;
 always @*begin
  next_x=x;next_y=y;next_phase=phase;
  if(y>0)begin next_x=x+(y>>>iteration);next_y=y-(x>>>iteration);next_phase=phase+angle(iteration);end
  else if(y<0)begin next_x=x-(y>>>iteration);next_y=y+(x>>>iteration);next_phase=phase-angle(iteration);end
  wrapped_phase=next_phase;
  if(next_phase>=33'sd1073741824)wrapped_phase=next_phase-33'sd2147483648;
  else if(next_phase< -33'sd1073741824)wrapped_phase=next_phase+33'sd2147483648;
 end
 assign request_ready=!rst&&state==IDLE&&!result_valid;
 assign busy=state!=IDLE||result_valid;
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;result_valid<=0;phase_q31<=0;zero_vector<=0;
   input_x<=0;input_y<=0;quadrant_x<=0;quadrant_y<=0;x<=0;y<=0;phase<=0;shift<=0;iteration<=0;
  end else begin
   if(result_valid&&result_ready)result_valid<=0;
   case(state)
    IDLE:if(request_valid&&request_ready)begin
     input_x<=x_in;input_y<=y_in;zero_vector<=x_in==0&&y_in==0;
     if(x_in==0&&y_in==0)begin result_valid<=1;phase_q31<=0;end
     else state<=PREPARE;
    end
    PREPARE:begin
     shift<=7'sd44-$signed({1'b0,highest});
     quadrant_x<=input_x<0?-input_x:input_x;quadrant_y<=input_x<0?-input_y:input_y;
     phase<=input_x<0?(input_y>=0?33'sd1073741824:-33'sd1073741824):33'sd0;
     state<=NORMALIZE;
    end
    NORMALIZE:begin
     x<=shift>=0?(quadrant_x<<<shift):(quadrant_x>>>(-shift));
     y<=shift>=0?(quadrant_y<<<shift):(quadrant_y>>>(-shift));
     iteration<=0;state<=ROTATE;
    end
    ROTATE:begin
     x<=next_x;y<=next_y;phase<=next_phase;
     if(iteration==30)begin phase_q31<=wrapped_phase[31:0];result_valid<=1;state<=IDLE;end
     else iteration<=iteration+1'b1;
    end
   endcase
  end
 end
endmodule
