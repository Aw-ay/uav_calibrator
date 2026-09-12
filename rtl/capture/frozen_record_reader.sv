// Frozen, immutable B128 RAM only. One reserved response credit: no request
// while a response or cached word exists. ram_data updates after request edge.
module frozen_record_reader (
 input wire clk,rst,desc_valid, output wire desc_ready,
 input wire [13:0] start_ptr,input wire [14:0] sample_count,
 output wire ram_en,output wire [12:0] ram_addr,input wire [127:0] ram_data,
 output wire sample_valid,input wire sample_ready,output wire [63:0] sample_data,
 output reg done,rejected,output wire busy
);
 import calibrator_contract_pkg::*;
 localparam IDLE=0,REQUEST=1,RESPONSE=2,HAVE=3;
 reg [1:0] state;reg[13:0] ptr;reg[14:0] remaining;reg[127:0] word_cache;
 assign desc_ready=state==IDLE;assign busy=state!=IDLE;
 assign ram_en=state==REQUEST;assign ram_addr=ptr[13:1];
 assign sample_valid=state==HAVE;
 assign sample_data=ptr[0]?word_cache[127:64]:word_cache[63:0];
 always @(posedge clk) begin
  if(rst)begin state<=IDLE;done<=0;rejected<=0;ptr<=0;remaining<=0;word_cache<=0;end
  else begin
   done<=0;rejected<=0;
   case(state)
    IDLE:if(desc_valid)begin
     if(sample_count==0 || sample_count>FRAME_MAX_SAMPLES)rejected<=1;
     else begin ptr<=start_ptr;remaining<=sample_count;state<=REQUEST;end
    end
    REQUEST:state<=RESPONSE;
    RESPONSE:begin word_cache<=ram_data;state<=HAVE;end
    HAVE:if(sample_ready)begin
     ptr<=ptr+1'b1;remaining<=remaining-1'b1;
     if(remaining==1)begin state<=IDLE;done<=1;end
     else if(ptr[0])state<=REQUEST;
    end
   endcase
  end
 end
endmodule
