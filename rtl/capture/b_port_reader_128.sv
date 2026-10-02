// Natural B words. READ_LATENCY_B is request edge -> registered consumer edge.
// All issued requests reserve FIFO credit, including responses still in flight.
// Warm cancellation uses abort, then waits done before releasing the bank token.
// rst is a cold/quiescent reset; it is not a substitute for abort/drain.
module b_port_reader_128 #(
 parameter integer READ_LATENCY_B=1,
 parameter integer FIFO_WORDS=8,
 parameter integer SAFETY_WORDS=1
)(
 input wire clk,rst,abort,desc_valid,output wire desc_ready,
 input wire[13:0] start_ptr,input wire[14:0] sample_count,
 output wire ram_en,output wire[12:0] ram_addr,input wire[127:0] ram_data,
 output wire word_valid,input wire word_ready,output wire[127:0] word_data,
 output wire[1:0] word_mask,output wire word_first,word_last,
 output wire[14:0] word_index,
 output reg done,rejected,output wire busy
);
 localparam PW=$clog2(FIFO_WORDS), CW=$clog2(FIFO_WORDS+1);
 reg active,draining,head;
 reg[12:0] address;reg[14:0] left,index;
 reg[PW-1:0] rd,wr;reg[CW-1:0] used,inflight;
 reg[127:0] data_fifo[0:FIFO_WORDS-1];
 reg[18:0] meta_fifo[0:FIFO_WORDS-1];
 reg[READ_LATENCY_B-1:0] pending;
 reg[18:0] meta_pipe[0:READ_LATENCY_B-1];
 wire response=pending[READ_LATENCY_B-1];
 wire odd_head=head;
 wire[1:0] lanes=odd_head?2'b10:(left==1?2'b01:2'b11);
 wire[1:0] consume=(lanes==2'b11)?2'd2:2'd1;
 wire request_last=left==consume;
 assign ram_en=active&&!draining&&!abort&&(left!=0)&&((used+inflight)<FIFO_WORDS-SAFETY_WORDS);
 assign ram_addr=address;
 assign desc_ready=!active&&!abort;
 assign busy=active;
 assign word_valid=active&&!draining&&!abort&&(used!=0);
 assign word_data=data_fifo[rd];
 assign {word_first,word_last,word_mask,word_index}=meta_fifo[rd];
 wire pop=word_valid&&word_ready;
 integer i;
 initial begin
  if(READ_LATENCY_B<1 || (FIFO_WORDS!=8&&FIFO_WORDS!=16) || SAFETY_WORDS<0 || SAFETY_WORDS>=FIFO_WORDS)
   $error("Invalid B128 reader parameters");
 end
 always @(posedge clk)begin
  if(rst)begin
   active<=0;draining<=0;head<=0;address<=0;left<=0;index<=0;
   rd<=0;wr<=0;used<=0;inflight<=0;pending<=0;done<=0;rejected<=0;
   for(i=0;i<READ_LATENCY_B;i=i+1)meta_pipe[i]<=0;
  end else begin
   done<=0;rejected<=0;
   pending[0]<=ram_en;
   meta_pipe[0]<={index==0,request_last,lanes,index};
   for(i=1;i<READ_LATENCY_B;i=i+1)begin pending[i]<=pending[i-1];meta_pipe[i]<=meta_pipe[i-1];end
   case({ram_en,response})
    2'b10:inflight<=inflight+1'b1;
    2'b01:inflight<=inflight-1'b1;
    default:begin end
   endcase
   if(ram_en)begin address<=address+1'b1;left<=left-consume;index<=index+consume;head<=0;end
   if(active&&(abort||draining))begin
    draining<=1;used<=0;rd<=0;wr<=0;
    if(pending==0)begin active<=0;draining<=0;done<=1;left<=0;end
   end else begin
    case({response,pop})
     2'b10:used<=used+1'b1;
     2'b01:used<=used-1'b1;
     default:begin end
    endcase
    if(response)begin data_fifo[wr]<=ram_data;meta_fifo[wr]<=meta_pipe[READ_LATENCY_B-1];wr<=wr+1'b1;end
    if(pop)begin rd<=rd+1'b1;if(word_last)begin active<=0;done<=1;end end
    if(desc_valid&&desc_ready)begin
     if(sample_count==0||sample_count>16384)rejected<=1;
     else begin
      active<=1;draining<=0;head<=start_ptr[0];address<=start_ptr[13:1];
      left<=sample_count;index<=0;used<=0;inflight<=0;rd<=0;wr<=0;
     end
    end
   end
  end
 end
endmodule
