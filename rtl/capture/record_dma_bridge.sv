// One record lease outstanding across clk_rf (125 MHz) / clk_mem (200 MHz).
// Caller MUST reserve/pin the immutable bank before publishing desc_valid.
// group/bank are zero-based physical indices; token consumer is implicitly record.
// m_axis_tready MUST mean durable ownership by a reliable downstream buffer/DMA
// chain. Completion is NOT reader_done and is NOT evidence of host delivery.
// error=1 means formatter rejected the descriptor; no RAM reads or bytes occurred.
// Reset contract: stop admission, drain/cancel and isolate RAM/AXIS/downstream,
// coordinate rst_n assertion across BOTH domains, increment owner epoch, rearm.
// Local reset release is synchronized. Independent domain reset is NOT supported;
// reset discards outstanding descriptors/completions and cannot itself release RAW.
module record_dma_bridge(
 input wire clk_rf,clk_mem,rst_n,
 input wire desc_valid,output wire desc_ready,
 input wire[1023:0] desc_header,input wire[13:0] desc_start,input wire[14:0] desc_count,
 input wire[63:0] desc_epoch,desc_generation,input wire[1:0] desc_group,desc_bank,
 output wire completion_valid,input wire completion_ready,output wire completion_error,
 output wire[63:0] completion_epoch,completion_generation,output wire[1:0] completion_group,completion_bank,
 output wire ram_en,output wire[12:0] ram_addr,output wire[1:0] ram_group,ram_bank,input wire[127:0] ram_data,
 output wire[127:0] m_axis_tdata,output wire[15:0] m_axis_tkeep,
 output wire m_axis_tvalid,input wire m_axis_tready,output wire m_axis_tlast
);
 (* ASYNC_REG="TRUE" *) reg[1:0] rf_reset,mem_reset;
 always @(posedge clk_rf or negedge rst_n)if(!rst_n)rf_reset<=0;else rf_reset<={rf_reset[0],1'b1};
 always @(posedge clk_mem or negedge rst_n)if(!rst_n)mem_reset<=0;else mem_reset<={mem_reset[0],1'b1};
 wire rf_run=rf_reset[1],mem_run=mem_reset[1];
 reg outstanding;
 wire request_busy,request_valid,request_take,return_busy,return_valid,return_send;
 wire[1184:0] request_data;
 wire[132:0] return_data;
 assign desc_ready=rf_run&&!outstanding&&!request_busy;
 always @(posedge clk_rf or negedge rst_n)begin
  if(!rst_n)outstanding<=0;
  else if(rf_run)begin
   if(desc_valid&&desc_ready)outstanding<=1;
   if(completion_valid&&completion_ready)outstanding<=0;
  end
 end
 cdc_mailbox #(.WIDTH(1185)) request_cdc(.src_clk(clk_rf),.dst_clk(clk_mem),.rst_n(rst_n),
  .src_send(desc_valid&&desc_ready),.src_data({desc_header,desc_start,desc_count,desc_epoch,desc_generation,desc_group,desc_bank}),
  .src_busy(request_busy),.src_done(),.dst_valid(request_valid),.dst_data(request_data),.dst_take(request_take));
 localparam IDLE=0,FORMAT=1,CHECK=2,READER=3,ACTIVE=4,RETURN=5;
 reg[2:0] state;reg[1023:0] header;reg[13:0] start;reg[14:0] count;reg[131:0] token;reg error;
 wire fready,fbusy,fdone,frejected,rready,rbusy,rdone,rrejected,sv,sr;
 wire[63:0] sample;
 assign request_take=mem_run&&state==IDLE;
 assign {ram_group,ram_bank}=token[3:0];
 assign return_send=mem_run&&state==RETURN&&!return_busy;
 cdc_mailbox #(.WIDTH(133)) completion_cdc(.src_clk(clk_mem),.dst_clk(clk_rf),.rst_n(rst_n),
  .src_send(return_send),.src_data({error,token}),.src_busy(return_busy),.src_done(),
  .dst_valid(return_valid),.dst_data(return_data),.dst_take(completion_valid&&completion_ready));
 assign completion_valid=rf_run&&return_valid;
 assign {completion_error,completion_epoch,completion_generation,completion_group,completion_bank}=return_data;
 // A handshake alone does not prove a valid header: formatter reports rejection
 // on the next cycle. CHECK observes that result before ever launching the reader.
 always @(posedge clk_mem)begin
  if(!mem_run)begin state<=IDLE;header<=0;start<=0;count<=0;token<=0;error<=0;end
  else case(state)
   IDLE:if(request_valid)begin {header,start,count,token}<=request_data;error<=0;state<=FORMAT;end
   FORMAT:if(fready)state<=CHECK;
   CHECK:if(frejected)begin error<=1;state<=RETURN;end else if(fbusy)state<=READER;
   READER:if(rready)state<=ACTIVE;
   ACTIVE:if(fdone)state<=RETURN;
   RETURN:if(!return_busy)state<=IDLE;
   default:state<=IDLE;
  endcase
 end
 frozen_record_reader reader(.clk(clk_mem),.rst(!mem_run),.desc_valid(mem_run&&state==READER),.desc_ready(rready),
  .start_ptr(start),.sample_count(count),.ram_en(ram_en),.ram_addr(ram_addr),.ram_data(ram_data),
  .sample_valid(sv),.sample_ready(sr),.sample_data(sample),.done(rdone),.rejected(rrejected),.busy(rbusy));
 record_formatter formatter(.clk(clk_mem),.rst(!mem_run),.desc_valid(mem_run&&state==FORMAT),.desc_ready(fready),
  .header_data(header),.sample_count(count),.sample_valid(sv),.sample_ready(sr),.sample_data(sample),
  .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready),.m_axis_tlast(m_axis_tlast),.done(fdone),.rejected(frejected),.busy(fbusy));
endmodule
