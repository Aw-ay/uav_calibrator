// Non-packet 128-bit AXIS storage, default 4096 total beats (output included).
// Accepted beats are owned until consumed. Coordinated reset cancels queued
// records; the system must report record loss and quiesce DMA before resetting.
// No combinational RAM read or dependence of valid on downstream ready.
module axis_record_fifo #(parameter integer ADDR_W=12)(
 input wire clk,rst,
 input wire [127:0] s_axis_tdata,input wire [15:0] s_axis_tkeep,
 input wire s_axis_tlast,s_axis_tvalid,output wire s_axis_tready,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,
 output wire m_axis_tlast,m_axis_tvalid,input wire m_axis_tready,
 output wire [ADDR_W:0] occupancy
);
 localparam integer DEPTH=1<<ADDR_W;
 (* ram_style="block" *) reg [144:0] memory [0:DEPTH-1];
 reg [ADDR_W-1:0] write_ptr,read_ptr;
 reg [ADDR_W:0] queued;
 reg [144:0] output_word;
 reg output_valid;
 wire push=s_axis_tvalid&&s_axis_tready;
 wire prefetch=(!output_valid||m_axis_tready)&&(queued!=0)&&!rst;
 assign occupancy=queued+output_valid;
 assign s_axis_tready=!rst&&(occupancy<DEPTH);
 assign m_axis_tvalid=output_valid&&!rst;
 assign {m_axis_tlast,m_axis_tkeep,m_axis_tdata}=output_word;
 // Keeping RAM write/read outside the reset branch permits BRAM inference.
 always @(posedge clk) begin
  if(push)memory[write_ptr]<={s_axis_tlast,s_axis_tkeep,s_axis_tdata};
  if(prefetch)output_word<=memory[read_ptr];
 end
 always @(posedge clk) begin
  if(rst)begin write_ptr<=0;read_ptr<=0;queued<=0;output_valid<=0;end
  else begin
   if(push)write_ptr<=write_ptr+1'b1;
   if(prefetch)begin read_ptr<=read_ptr+1'b1;output_valid<=1;end
   else if(m_axis_tready)output_valid<=0;
   case({push,prefetch})
    2'b10:queued<=queued+1'b1;
    2'b01:queued<=queued-1'b1;
    default:begin end
   endcase
  end
 end
endmodule
