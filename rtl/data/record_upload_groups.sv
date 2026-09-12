// Four FIFO-like RF descriptor sources, one nonpreemptive upload path.
// Source index is the physical stream group (0..3), never inferred from gain.
// Producers pin banks and freeze metadata before asserting valid. This module
// schedules approved records only; it does not decide pulse/range qualification.
module record_upload_groups #(parameter integer FIFO_ADDR_W=12)(
 input wire clk_rf,clk_mem,rst_n,
 input wire [3:0] desc_valid,output wire [3:0] desc_ready,
 input wire [4095:0] desc_headers,input wire [55:0] desc_starts,
 input wire [59:0] desc_counts,input wire [255:0] desc_epochs,desc_generations,
 input wire [7:0] desc_banks,
 output wire completion_valid,input wire completion_ready,output wire completion_error,
 output wire [63:0] completion_epoch,completion_generation,
 output wire [1:0] completion_group,completion_bank,
 output wire [15:0] record_enable,record_lease,
 output wire [207:0] record_address,input wire [2047:0] record_data,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,
 output wire m_axis_tlast,m_axis_tvalid,input wire m_axis_tready,
 output wire [FIFO_ADDR_W:0] fifo_occupancy,
 // RF reader quiescence only: FIFO can still own bytes awaiting DMA.
 output wire idle_rf
);
 localparam integer WIDTH=1183;
 wire [4*WIDTH-1:0] source_data;
 wire [WIDTH-1:0] selected_data;
 wire [1:0] selected_group;
 wire selected_valid,selected_ready;
 wire arbiter_busy;
 assign idle_rf=rf_reset[1]&&!arbiter_busy&&selected_ready;
 wire [1023:0] header;
 wire [13:0] start;
 wire [14:0] count;
 wire [63:0] epoch,generation;
 wire [1:0] bank;
 (* ASYNC_REG="TRUE" *) reg [1:0] rf_reset;
 always @(posedge clk_rf or negedge rst_n)
  if(!rst_n)rf_reset<=0;else rf_reset<={rf_reset[0],1'b1};
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: pack_descriptor
  assign source_data[g*WIDTH+:WIDTH]={desc_headers[g*1024+:1024],desc_starts[g*14+:14],desc_counts[g*15+:15],desc_epochs[g*64+:64],desc_generations[g*64+:64],desc_banks[g*2+:2]};
 end endgenerate
 assign {header,start,count,epoch,generation,bank}=selected_data;
 record_descriptor_arbiter #(.WIDTH(WIDTH)) arbiter(
  .clk(clk_rf),.rst(!rf_reset[1]),.s_valid(desc_valid),.s_ready(desc_ready),.s_data(source_data),
  .m_valid(selected_valid),.m_ready(selected_ready),.m_data(selected_data),.m_group(selected_group),
  .record_done(completion_valid&&completion_ready),.busy(arbiter_busy));
 record_upload_path #(.FIFO_ADDR_W(FIFO_ADDR_W)) upload(
  .clk_rf(clk_rf),.clk_mem(clk_mem),.rst_n(rst_n),
  .desc_valid(selected_valid),.desc_ready(selected_ready),.desc_header(header),
  .desc_start(start),.desc_count(count),.desc_epoch(epoch),.desc_generation(generation),
  .desc_group(selected_group),.desc_bank(bank),
  .completion_valid(completion_valid),.completion_ready(completion_ready),.completion_error(completion_error),
  .completion_epoch(completion_epoch),.completion_generation(completion_generation),
  .completion_group(completion_group),.completion_bank(completion_bank),
  .record_enable(record_enable),.record_lease(record_lease),.record_address(record_address),.record_data(record_data),
  .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),
  .m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready),.fifo_occupancy(fifo_occupancy));
endmodule
