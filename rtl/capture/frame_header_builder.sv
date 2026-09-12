// Frozen metadata supplies semantic IDs and quality flags. Window-derived fields
// are built only after capture completes. The downstream formatter owns CRC.
module frame_header_builder(
 input wire clk,rst,request_valid,output wire request_ready,
 input wire [1023:0] template_header,input wire [14:0] sample_count,
 input wire [63:0] window_start_seq,time_origin_seq,time_origin_gsc,
 output reg result_valid,input wire result_ready,
 output reg [1023:0] header_data,output reg rejected
);
 import calibrator_contract_pkg::*;
 wire [63:0] delta=window_start_seq-time_origin_seq;
 wire [66:0] first_tick={3'b0,time_origin_gsc}+{1'b0,delta,2'b0};
 wire [31:0] payload_bytes={17'b0,sample_count}<<3;
 wire [31:0] flags=template_header[FRAME_QUALITY_FLAGS_OFFSET*8+:32];
 wire trailer=(flags&QUALITY_HAS_CRC_TRAILER)!=0;
 wire legal=sample_count!=0&&sample_count<=FRAME_MAX_SAMPLES&&
            window_start_seq>=time_origin_seq&&first_tick[66:64]==0;
 assign request_ready=!result_valid||result_ready;
 always @(posedge clk)begin
  if(rst)begin result_valid<=0;header_data<=0;rejected<=0;end
  else begin
   rejected<=0;
   if(result_valid&&result_ready)result_valid<=0;
   if(request_valid&&request_ready)begin
    if(!legal)rejected<=1;
    else begin
     result_valid<=1;header_data<=template_header;
     header_data[FRAME_MAGIC_OFFSET*8+:32]<=FRAME_MAGIC;
     header_data[FRAME_SCHEMA_VERSION_OFFSET*8+:16]<=FRAME_ABI_VERSION;
     header_data[FRAME_HEADER_BYTES_OFFSET*8+:16]<=FRAME_HEADER_BYTES;
     header_data[FRAME_RECORD_BYTES_OFFSET*8+:32]<=FRAME_HEADER_BYTES+payload_bytes+(trailer?FRAME_TRAILER_BYTES:0);
     header_data[FRAME_PAYLOAD_BYTES_OFFSET*8+:32]<=payload_bytes;
     header_data[FRAME_SAMPLE_COUNT_OFFSET*8+:32]<={17'b0,sample_count};
     header_data[FRAME_GSC_FIRST_OFFSET*8+:64]<=first_tick[63:0];
     header_data[FRAME_SAMPLE_STRIDE_TICKS_OFFSET*8+:32]<=SYS_RATES_PL_DECIMATION;
     header_data[FRAME_SAMPLE_RATE_NUM_OFFSET*8+:32]<=SYS_RATES_CORE_COMPLEX_HZ;
     header_data[FRAME_SAMPLE_RATE_DEN_OFFSET*8+:32]<=1;
     header_data[FRAME_HEADER_CRC32C_OFFSET*8+:32]<=0;
     header_data[FRAME_RESERVED_OFFSET*8+:32]<=0;
    end
   end
  end
 end
endmodule
