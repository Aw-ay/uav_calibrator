// ABI v5 formatter. Payload remains 128 bits throughout the DMA path.
// CRC is a generated parallel GF(2) transform, one 128-bit payload each cycle.
module record_formatter_128 (
 input wire clk,rst,desc_valid,output wire desc_ready,
 input wire[1023:0] header_data,input wire[14:0] sample_count,
 input wire payload_valid,output wire payload_ready,input wire[127:0] payload_data,
 input wire[15:0] payload_keep,input wire payload_last,
 output reg[127:0] m_axis_tdata,output reg[15:0] m_axis_tkeep,
 output reg m_axis_tvalid,input wire m_axis_tready,output reg m_axis_tlast,
 output reg done,rejected,output wire busy
);
 import calibrator_contract_pkg::*;
 import crc32c_parallel_pkg::*;
 localparam IDLE=0,CRC_HEADER=1,HEADER=2,PAYLOAD=3,TRAILER=4,DRAIN=5;
 reg[2:0] state;reg[1023:0] header_buf;
 reg[2:0] header_index,crc_index;reg[31:0] hcrc,pcrc,payload_bytes;
 reg[14:0] remaining;reg trailer_enabled,odd_tail;
 wire[31:0] flags=header_data[FRAME_QUALITY_FLAGS_OFFSET*8+:32];
 wire has_trailer=(flags&QUALITY_HAS_CRC_TRAILER)!=0;
 wire[31:0] expected_payload={17'b0,sample_count}*FRAME_PAYLOAD_SAMPLE_BYTES;
 wire header_ok=sample_count!=0 && sample_count<=FRAME_MAX_SAMPLES
  && header_data[FRAME_MAGIC_OFFSET*8+:32]==FRAME_MAGIC
  && header_data[FRAME_SCHEMA_VERSION_OFFSET*8+:16]==FRAME_ABI_VERSION
  && header_data[FRAME_HEADER_BYTES_OFFSET*8+:16]==FRAME_HEADER_BYTES
  && header_data[FRAME_SAMPLE_COUNT_OFFSET*8+:32]=={17'b0,sample_count}
  && header_data[FRAME_PAYLOAD_BYTES_OFFSET*8+:32]==expected_payload
  && header_data[FRAME_RECORD_BYTES_OFFSET*8+:32]==FRAME_HEADER_BYTES+expected_payload+(has_trailer?FRAME_TRAILER_BYTES:0)
  && header_data[FRAME_SAMPLE_STRIDE_TICKS_OFFSET*8+:32]!=0
  && header_data[FRAME_SAMPLE_RATE_NUM_OFFSET*8+:32]!=0
  && header_data[FRAME_SAMPLE_RATE_DEN_OFFSET*8+:32]!=0
  && header_data[FRAME_RESERVED_OFFSET*8+:32]==0;

 wire slot=!m_axis_tvalid||m_axis_tready;
 wire[31:0] next_pcrc=remaining==1?crc64(pcrc,payload_data[63:0]):crc128(pcrc,payload_data);
 wire[31:0] next_hcrc=crc128(hcrc,header_buf[crc_index*128+:128]);
 assign desc_ready=state==IDLE;
 assign busy=state!=IDLE;
 assign payload_ready=state==PAYLOAD&&slot;
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;m_axis_tvalid<=0;m_axis_tdata<=0;m_axis_tkeep<=0;m_axis_tlast<=0;
   done<=0;rejected<=0;header_buf<=0;header_index<=0;crc_index<=0;hcrc<=0;pcrc<=0;
   payload_bytes<=0;remaining<=0;trailer_enabled<=0;odd_tail<=0;
  end else begin
   done<=0;rejected<=0;
   if(m_axis_tvalid&&m_axis_tready)begin
    m_axis_tvalid<=0;
    if(m_axis_tlast)begin done<=1;state<=IDLE;end
   end
   case(state)
    IDLE:if(desc_valid)begin
     if(!header_ok)rejected<=1;
     else begin
      header_buf<=header_data;header_buf[FRAME_HEADER_CRC32C_OFFSET*8+:32]<=0;
      remaining<=sample_count;payload_bytes<=expected_payload;trailer_enabled<=has_trailer;
      hcrc<=32'hffffffff;pcrc<=32'hffffffff;header_index<=0;crc_index<=0;odd_tail<=0;
      state<=(flags&QUALITY_CRC_DISABLED)!=0?HEADER:CRC_HEADER;
     end
    end
    CRC_HEADER:begin
     hcrc<=next_hcrc;
     if(crc_index==7)begin header_buf[FRAME_HEADER_CRC32C_OFFSET*8+:32]<=~next_hcrc;state<=HEADER;end
     else crc_index<=crc_index+1'b1;
    end
    HEADER:if(slot)begin
     m_axis_tdata<=header_buf[header_index*128+:128];m_axis_tkeep<=16'hffff;
     m_axis_tvalid<=1;m_axis_tlast<=0;
     if(header_index==7)state<=PAYLOAD;else header_index<=header_index+1'b1;
    end
    PAYLOAD:if(payload_valid&&payload_ready)begin
     pcrc<=next_pcrc;m_axis_tvalid<=1;
     if(remaining==1)begin
      m_axis_tdata<=trailer_enabled?{~next_pcrc,FRAME_TRAILER_MAGIC,payload_data[63:0]}:{64'b0,payload_data[63:0]};
      m_axis_tkeep<=trailer_enabled?16'hffff:16'h00ff;
      m_axis_tlast<=!trailer_enabled;remaining<=0;odd_tail<=1;state<=trailer_enabled?TRAILER:DRAIN;
     end else begin
      m_axis_tdata<=payload_data;m_axis_tkeep<=16'hffff;
      m_axis_tlast<=remaining==2&&!trailer_enabled;remaining<=remaining-2;
      if(remaining==2)state<=trailer_enabled?TRAILER:DRAIN;
     end
    end
    TRAILER:if(slot)begin
     m_axis_tdata<=odd_tail?{64'b0,32'b0,payload_bytes}:{32'b0,payload_bytes,~pcrc,FRAME_TRAILER_MAGIC};
     m_axis_tkeep<=odd_tail?16'h00ff:16'hffff;m_axis_tlast<=1;m_axis_tvalid<=1;state<=DRAIN;
    end
    default:begin end
   endcase
  end
 end
 // Internal producer must obey compact payload shape. Headers are rejected before
 // any bytes; malformed internal payload is a design fault, not a partial success.
`ifndef SYNTHESIS
 always @(posedge clk)if(!rst&&payload_valid&&payload_ready)begin
  if(payload_keep!==(remaining==1?16'h00ff:16'hffff)||payload_last!==(remaining<=2))
   $fatal(1,"invalid compact payload length/last");
 end
`endif
endmodule
