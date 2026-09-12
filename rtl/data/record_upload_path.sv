// Frozen descriptor -> RAM B ports -> ABI5 -> owned FIFO -> DMA S2MM.
// One outstanding record. The caller pins the bank before desc_valid and keeps
// it immutable until accepting the completion token. Error completions must be
// recorded as rejected/lost descriptors by the owner, never as delivered frames.
// All resets require system quiescence/isolation; FIFO contents are lost on reset.
module record_upload_path #(parameter integer FIFO_ADDR_W=12)(
 input wire clk_rf,clk_mem,rst_n,
 input wire desc_valid,output wire desc_ready,
 input wire [1023:0] desc_header,input wire [13:0] desc_start,
 input wire [14:0] desc_count,input wire [63:0] desc_epoch,desc_generation,
 input wire [1:0] desc_group,desc_bank,
 output wire completion_valid,input wire completion_ready,output wire completion_error,
 output wire [63:0] completion_epoch,completion_generation,
 output wire [1:0] completion_group,completion_bank,
 // Directly connect these to capture_bank_array in the clk_mem domain. A read
// enable is itself covered by the immutable descriptor's lease, not a sampled
// asynchronous frozen_rf mask. The RAM response latency must be one clock.
 output wire [15:0] record_enable,record_lease,
 output wire [207:0] record_address,input wire [2047:0] record_data,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,
 output wire m_axis_tlast,m_axis_tvalid,input wire m_axis_tready,
 output wire [FIFO_ADDR_W:0] fifo_occupancy
);
 wire ram_en;
 wire [12:0] ram_addr;
 wire [1:0] ram_group,ram_bank;
 wire [3:0] index={ram_group,ram_bank};
 wire [127:0] stream_data;
 wire [15:0] stream_keep;
 wire stream_last,stream_valid,stream_ready;
 assign record_enable=(16'b1<<index)&{16{ram_en&&rst_n}};
 assign record_lease=record_enable;
 genvar b;
 generate for(b=0;b<16;b=b+1)begin: address_broadcast
  assign record_address[b*13+:13]=ram_addr;
 end endgenerate
 record_dma_bridge bridge(
  .clk_rf(clk_rf),.clk_mem(clk_mem),.rst_n(rst_n),
  .desc_valid(desc_valid),.desc_ready(desc_ready),.desc_header(desc_header),
  .desc_start(desc_start),.desc_count(desc_count),.desc_epoch(desc_epoch),
  .desc_generation(desc_generation),.desc_group(desc_group),.desc_bank(desc_bank),
  .completion_valid(completion_valid),.completion_ready(completion_ready),
  .completion_error(completion_error),.completion_epoch(completion_epoch),
  .completion_generation(completion_generation),.completion_group(completion_group),
  .completion_bank(completion_bank),.ram_en(ram_en),.ram_addr(ram_addr),
  .ram_group(ram_group),.ram_bank(ram_bank),.ram_data(record_data[index*128+:128]),
  .m_axis_tdata(stream_data),.m_axis_tkeep(stream_keep),.m_axis_tlast(stream_last),
  .m_axis_tvalid(stream_valid),.m_axis_tready(stream_ready));
 axis_record_fifo #(.ADDR_W(FIFO_ADDR_W)) fifo(
  .clk(clk_mem),.rst(!rst_n),.s_axis_tdata(stream_data),.s_axis_tkeep(stream_keep),
  .s_axis_tlast(stream_last),.s_axis_tvalid(stream_valid),.s_axis_tready(stream_ready),
  .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),
  .m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready),.occupancy(fifo_occupancy));
endmodule
