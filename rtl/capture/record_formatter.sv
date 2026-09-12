// C07 bounded record serializer. Caller supplies complete ABI metadata; semantic
// format/calibration/source qualification remains caller responsibility. Only
// header CRC is overwritten. Byte 0 occupies header_data[7:0]. No CDC here.
module record_formatter (
 input wire clk,rst,desc_valid,output wire desc_ready,
 input wire[1023:0] header_data,input wire[14:0] sample_count,
 input wire sample_valid,output wire sample_ready,input wire[63:0] sample_data,
 output reg[127:0] m_axis_tdata,output reg[15:0] m_axis_tkeep,
 output reg m_axis_tvalid,input wire m_axis_tready,output reg m_axis_tlast,
 output reg done,rejected,output wire busy
);
 import calibrator_contract_pkg::*;
 localparam IDLE=0,CRC_HEADER=1,HEADER=2,PAYLOAD=3,TRAILER=4,DRAIN=5;
 reg[2:0] state;reg[1023:0] header_buf;reg[6:0] crc_index;
 reg[3:0] header_index;reg[31:0] hcrc,pcrc,payload_bytes;
 reg[14:0] remaining;reg trailer_enabled,half_full,odd_tail;
 reg[63:0] half_sample;
 function automatic [31:0] crc_byte(input[31:0] c,input[7:0] b);
  reg[31:0] x;integer k;begin x=c^{24'b0,b};for(k=0;k<8;k=k+1)x=(x>>1)^(x[0]?32'h82f63b78:32'b0);crc_byte=x;end
 endfunction
 function automatic[31:0] crc_sample(input[31:0] c,input[63:0] s);
  reg[31:0] x;integer k;begin x=c;for(k=0;k<8;k=k+1)x=crc_byte(x,s[k*8+:8]);crc_sample=x;end
 endfunction
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
 wire[31:0] next_pcrc=crc_sample(pcrc,sample_data);
 assign desc_ready=state==IDLE;assign busy=state!=IDLE;
 assign sample_ready=state==PAYLOAD && !m_axis_tvalid;
 always @(posedge clk) begin
  if(rst)begin
   state<=IDLE;m_axis_tvalid<=0;m_axis_tdata<=0;m_axis_tkeep<=0;m_axis_tlast<=0;done<=0;rejected<=0;
   header_buf<=0;crc_index<=0;header_index<=0;hcrc<=0;pcrc<=0;payload_bytes<=0;remaining<=0;trailer_enabled<=0;half_full<=0;odd_tail<=0;half_sample<=0;
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
      hcrc<=32'hffffffff;pcrc<=32'hffffffff;crc_index<=0;header_index<=0;half_full<=0;odd_tail<=0;
      state<=(flags&QUALITY_CRC_DISABLED)!=0?HEADER:CRC_HEADER;
     end
    end
    CRC_HEADER:begin
     hcrc<=crc_byte(hcrc,header_buf[crc_index*8+:8]);
     if(crc_index==FRAME_HEADER_BYTES-1)begin
      header_buf[FRAME_HEADER_CRC32C_OFFSET*8+:32]<=~crc_byte(hcrc,header_buf[crc_index*8+:8]);state<=HEADER;
     end else crc_index<=crc_index+1'b1;
    end
    HEADER:if(!m_axis_tvalid)begin
     m_axis_tdata<=header_buf[header_index*128+:128];m_axis_tkeep<=16'hffff;m_axis_tlast<=0;m_axis_tvalid<=1;
     if(header_index==7)state<=PAYLOAD;else header_index<=header_index+1'b1;
    end
    PAYLOAD:if(sample_valid&&sample_ready)begin
     pcrc<=next_pcrc;remaining<=remaining-1'b1;
     if(half_full)begin
      m_axis_tdata<={sample_data,half_sample};m_axis_tkeep<=16'hffff;m_axis_tvalid<=1;
      m_axis_tlast<=remaining==1&&!trailer_enabled;half_full<=0;
      if(remaining==1)state<=trailer_enabled?TRAILER:DRAIN;
     end else if(remaining==1)begin
      m_axis_tdata<=trailer_enabled?{~next_pcrc,FRAME_TRAILER_MAGIC,sample_data}:{64'b0,sample_data};
      m_axis_tkeep<=trailer_enabled?16'hffff:16'h00ff;m_axis_tlast<=!trailer_enabled;m_axis_tvalid<=1;
      odd_tail<=1;state<=trailer_enabled?TRAILER:DRAIN;
     end else begin half_sample<=sample_data;half_full<=1;end
    end
    TRAILER:if(!m_axis_tvalid)begin
     m_axis_tdata<=odd_tail?{64'b0,32'b0,payload_bytes}:{32'b0,payload_bytes,~pcrc,FRAME_TRAILER_MAGIC};
     m_axis_tkeep<=odd_tail?16'h00ff:16'hffff;m_axis_tlast<=1;m_axis_tvalid<=1;state<=DRAIN;
    end
    DRAIN:begin end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
