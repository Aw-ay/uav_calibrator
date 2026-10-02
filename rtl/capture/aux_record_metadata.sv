// Atomic RAW header and sidecar pair. Neither output grants/releases ownership.
module aux_record_metadata #(parameter integer PHYSICAL_MASKS_IN_TEMPLATE=0)(
 input wire clk,rst,request_valid,result_ready,bound,
 input wire [1023:0] template_header,
 input wire [31:0] metadata_id,epoch_id,source_epoch,h_calibration_id,v_calibration_id,config_id,fir_id,
 input wire [63:0] capture_id,owner_epoch,generation,tx_token,start_seq,start_gsc,
 input wire [14:0] sample_count,
 input wire [7:0] source_role,status,
 input wire [3:0] bank,
 output wire request_ready,result_valid,rejected,
 output wire [1023:0] header_data,
 output reg [767:0] metadata_data
);
 import calibrator_contract_pkg::*;
 import aux_metadata_pkg::*;
 wire legal=bound && metadata_id!=0 && capture_id!=0 && bank<4 && (source_role==2 || source_role==3) && status[7:5]==0;
 reg local_rejected;
 wire header_rejected;
 assign rejected=local_rejected|header_rejected;
 reg [1023:0] frozen_template;
 reg [31:0] flags;
 always @* begin
   frozen_template=template_header;
   flags=template_header[FRAME_QUALITY_FLAGS_OFFSET*8+:32];
   if(status!=0) flags=flags|QUALITY_INVALID;
   if(status[0]) flags=flags|QUALITY_SOURCE_SETTLING|QUALITY_CAL_UNQUALIFIED;
   if(status[1]) flags=flags|QUALITY_SAMPLE_GAP;
   if(status[4]) flags=flags|QUALITY_TRUNCATED;
   frozen_template[FRAME_QUALITY_FLAGS_OFFSET*8+:32]=flags;
   frozen_template[FRAME_PULSE_ID_OFFSET*8+:64]=capture_id;
   frozen_template[FRAME_EPOCH_ID_OFFSET*8+:32]=epoch_id;
   frozen_template[FRAME_CONFIG_ID_OFFSET*8+:32]=config_id;
   frozen_template[FRAME_FIR_ID_OFFSET*8+:32]=fir_id;
   frozen_template[FRAME_METADATA_ID_OFFSET*8+:32]=metadata_id;
   frozen_template[FRAME_RX_CAL_ID_OFFSET*8+:32]=0;
   frozen_template[FRAME_RANGE_ID_OFFSET*8+:8]=2;
   frozen_template[FRAME_CHANNEL_MASK_OFFSET*8+:8]=3;
   frozen_template[FRAME_STREAM_GROUP_ID_OFFSET*8+:8]=4;
   frozen_template[FRAME_PHYSICAL_ADC_MASK_OFFSET*8+:8]=PHYSICAL_MASKS_IN_TEMPLATE?template_header[FRAME_PHYSICAL_ADC_MASK_OFFSET*8+:8]:8'h88;
   frozen_template[FRAME_SOURCE_ROLE_OFFSET*8+:8]=source_role;
   frozen_template[FRAME_SOURCE_FLAGS_OFFSET*8+:8]=8'h08 | (status[0]?8'h03:0) | (status[1]?8'h04:0);
   frozen_template[FRAME_SOURCE_EPOCH_OFFSET*8+:32]=source_epoch;
 end
 frame_header_builder header_builder(
  .clk(clk),.rst(rst),.request_valid(request_valid&&legal),.request_ready(request_ready),
  .template_header(frozen_template),.sample_count(sample_count),.window_start_seq(start_seq),
  .time_origin_seq(start_seq),.time_origin_gsc(start_gsc),.result_valid(result_valid),
  .result_ready(result_ready),.header_data(header_data),.rejected(header_rejected));
 always @(posedge clk) begin
  if(rst) begin metadata_data<=0;local_rejected<=0;end
  else begin
   local_rejected<=request_valid && request_ready && !legal;
   if(request_valid && request_ready && legal && sample_count!=0 && sample_count<=16384) begin
    metadata_data<=0;
    metadata_data[AUX_META_MAGIC_OFFSET*8+:32]<=AUX_META_MAGIC;
    metadata_data[AUX_META_VERSION_OFFSET*8+:16]<=AUX_META_VERSION;
    metadata_data[AUX_META_BYTES_OFFSET*8+:16]<=AUX_META_BYTES;
    metadata_data[AUX_META_METADATA_ID_OFFSET*8+:32]<=metadata_id;
    metadata_data[AUX_META_EPOCH_ID_OFFSET*8+:32]<=epoch_id;
    metadata_data[AUX_META_CAPTURE_ID_OFFSET*8+:64]<=capture_id;
    metadata_data[AUX_META_OWNER_EPOCH_OFFSET*8+:64]<=owner_epoch;
    metadata_data[AUX_META_GENERATION_OFFSET*8+:64]<=generation;
    metadata_data[AUX_META_TX_TOKEN_OFFSET*8+:64]<=tx_token;
    metadata_data[AUX_META_START_SEQ_OFFSET*8+:64]<=start_seq;
    metadata_data[AUX_META_START_GSC_OFFSET*8+:64]<=start_gsc;
    metadata_data[AUX_META_SOURCE_EPOCH_OFFSET*8+:32]<=source_epoch;
    metadata_data[AUX_META_H_CALIBRATION_ID_OFFSET*8+:32]<=h_calibration_id;
    metadata_data[AUX_META_V_CALIBRATION_ID_OFFSET*8+:32]<=v_calibration_id;
    metadata_data[AUX_META_CONFIG_ID_OFFSET*8+:32]<=config_id;
    metadata_data[AUX_META_FIR_ID_OFFSET*8+:32]<=fir_id;
    metadata_data[AUX_META_SAMPLE_COUNT_OFFSET*8+:32]<={17'd0,sample_count};
    metadata_data[AUX_META_SOURCE_ROLE_OFFSET*8+:8]<=source_role;
    metadata_data[AUX_META_BANK_OFFSET*8+:8]<={4'd0,bank};
    metadata_data[AUX_META_STATUS_OFFSET*8+:8]<=status;
   end
  end
 end
endmodule
