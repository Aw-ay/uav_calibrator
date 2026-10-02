// DMA-only compaction. Fine uses the natural masked B words directly.
// A one-sample carry allows odd starts at full 128-bit input/output rate.
module dma_payload_packer(
 input wire clk,rst,abort,
 input wire s_valid,output wire s_ready,input wire[127:0] s_data,
 input wire[1:0] s_mask,input wire s_last,
 output reg m_valid,input wire m_ready,output reg[127:0] m_data,
 output reg[15:0] m_keep,output reg m_last
);
 reg carry_valid,flush;reg[63:0] carry;
 wire slot=!m_valid||m_ready;
 wire[63:0] lo=s_mask[0]?s_data[63:0]:s_data[127:64];
 wire two=s_mask==2'b11;
 assign s_ready=slot&&!flush&&!abort;
 always @(posedge clk)begin
  if(rst||abort)begin m_valid<=0;m_data<=0;m_keep<=0;m_last<=0;carry_valid<=0;flush<=0;carry<=0;end
  else if(slot)begin
   m_valid<=0;
   if(flush)begin
    m_data<={64'b0,carry};m_keep<=16'h00ff;m_last<=1;m_valid<=1;flush<=0;carry_valid<=0;
   end else if(s_valid&&s_ready)begin
    if(carry_valid)begin
     m_data<={lo,carry};m_keep<=16'hffff;m_valid<=1;m_last<=s_last&&!two;
     carry_valid<=two;
     if(two)begin carry<=s_data[127:64];flush<=s_last;end
    end else if(two)begin
     m_data<=s_data;m_keep<=16'hffff;m_last<=s_last;m_valid<=1;
    end else if(s_last)begin
     m_data<={64'b0,lo};m_keep<=16'h00ff;m_last<=1;m_valid<=1;
    end else begin carry<=lo;carry_valid<=1;end
   end
  end
 end
endmodule
