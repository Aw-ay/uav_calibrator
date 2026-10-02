// Natural B128 -> 32 logical H/V samples, two-sample retirement, no compacting across RAM words.
// All handshakes use pre-edge state; peek returns pre-edge data one cycle later.
// Abort cancels local work only: the owner MUST separately drain the B reader.
module fine_sample_cache_2(
 input wire clk,rst,abort,job_valid,output wire job_ready,
 input wire [14:0] job_count,input wire job_odd,
 input wire word_valid,output wire word_ready,input wire [127:0] word_data,
 input wire [1:0] word_mask,input wire [14:0] word_index,input wire word_first,word_last,
 output wire sample_valid,input wire sample_ready,output wire [127:0] sample_data,output wire [1:0] lane_count,
 output wire [14:0] sample_index,output wire sample_last,output reg [5:0] occupancy,
 output reg busy,done,error,
 input wire peek_req_valid,output wire peek_req_ready,input wire [14:0] peek_index,
 output wire peek_valid,input wire peek_ready,output reg peek_found,
 output reg [63:0] peek_data,output reg [14:0] peek_result_index
);
 reg [63:0] memory[0:31];
 reg [4:0] rd,wr;reg [14:0] base,accepted,total;reg odd,peek_pending;
 wire enabled=!rst&&!abort;
 wire [1:0] lanes=(word_mask==3)?2'd2:2'd1;
 wire [1:0] expected_mask=(accepted==0&&odd)?2'b10:
                          ((total-accepted==1)?2'b01:2'b11);
 wire [1:0] expected_lanes=(expected_mask==3)?2'd2:2'd1;
 wire malformed=(word_mask!=expected_mask)||(word_index!=accepted)||
       (word_first!=(accepted==0))||(word_last!=(accepted+expected_lanes==total));
 assign job_ready=!busy&&!peek_pending&&enabled;
 assign word_ready=busy&&(accepted<total)&&(occupancy<=32-lanes+(sample_valid&&sample_ready?lane_count:2'd0))&&enabled;
 assign sample_valid=busy&&(occupancy!=0)&&enabled;
 wire [4:0] rd_next=rd+5'd1;
 assign lane_count=occupancy>=2?2'd2:2'd1;
 assign sample_data=sample_valid?{occupancy>=2?memory[rd_next]:64'd0,memory[rd]}:128'd0;
 assign sample_index=sample_valid?base:15'd0;
 assign sample_last=sample_valid&&(base+lane_count==total);
 assign peek_req_ready=busy&&enabled&&(!peek_pending||peek_ready);
 assign peek_valid=peek_pending&&enabled;
 wire push=word_valid&&word_ready,pop=sample_valid&&sample_ready;
 wire [4:0] wr_next=wr+5'd1;
 wire [14:0] peek_offset=peek_index-base;
 wire peek_hit=(peek_index>=base)&&(peek_offset<occupancy);
 wire [4:0] peek_address=rd+peek_offset[4:0];
 always @(posedge clk)begin
  if(rst||abort)begin
   rd<=0;wr<=0;base<=0;accepted<=0;total<=0;odd<=0;occupancy<=0;
   busy<=0;done<=0;error<=0;peek_pending<=0;peek_found<=0;peek_data<=0;peek_result_index<=0;
  end else begin
   done<=0;error<=0;
   if(peek_req_valid&&peek_req_ready)begin
    peek_pending<=1;peek_result_index<=peek_index;peek_found<=peek_hit;
    peek_data<=peek_hit?memory[peek_address]:64'd0;
   end else if(peek_pending&&peek_ready)peek_pending<=0;
   case({push,pop})
    2'b10:occupancy<=occupancy+lanes;
    2'b01:occupancy<=occupancy-lane_count;
    2'b11:occupancy<=occupancy+lanes-lane_count;
    default:begin end
   endcase
   if(pop)begin
    rd<=rd+lane_count;base<=base+lane_count;
    if(sample_last)begin busy<=0;done<=1;end
   end
   if(push)begin
    if(malformed)begin busy<=0;occupancy<=0;peek_pending<=0;error<=1;end
    else begin
     memory[wr]<=word_mask[0]?word_data[63:0]:word_data[127:64];
     if(word_mask==3)memory[wr_next]<=word_data[127:64];
     wr<=wr+lanes;accepted<=accepted+lanes;
    end
   end
   if(job_valid&&job_ready)begin
    if(job_count==0||job_count>16384)error<=1;
    else begin
     busy<=1;rd<=0;wr<=0;base<=0;accepted<=0;occupancy<=0;total<=job_count;odd<=job_odd;
    end
   end
  end
 end
endmodule
