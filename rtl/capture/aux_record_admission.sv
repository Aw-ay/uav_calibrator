// Completion adapter. rst is a cold/session reset, never the bank soft reset.
// Downstream must revalidate ownership again before publishing/reading RAW.
module aux_record_admission #(
 parameter [31:0] MAX_METADATA_ID=32'hffffffff,
 parameter integer PHYSICAL_MASKS_IN_TEMPLATE=0
)(
 input wire clk,rst,request_valid,result_ready,bound,block_new_work,
 input wire [1023:0] template_header,
 input wire [31:0] epoch_id,source_epoch,h_calibration_id,v_calibration_id,config_id,fir_id,
 input wire [63:0] capture_id,owner_epoch,generation,tx_token,start_seq,start_gsc,
 input wire [14:0] requested_count,
 input wire [7:0] source_role,status,
 input wire [3:0] bank,
 input wire [63:0] live_owner_epoch,
 input wire [3:0] pending,frozen,truncated,
 input wire [255:0] bank_generation,bank_capture_id,bank_start_seq,
 input wire [59:0] bank_sample_count,
 output wire request_ready,result_valid,rejected,capacity_available,
 output reg id_exhausted,
 output reg [31:0] reject_count,
 output wire [1023:0] header_data,
 output wire [767:0] metadata_data
);
 wire [1:0] slot=bank[1:0];
 wire [14:0] actual_count=bank_sample_count[slot*15+:15];
 wire owner_ok=bound && bank<4 && pending[slot] && !frozen[slot] &&
   owner_epoch==live_owner_epoch && generation==bank_generation[slot*64+:64] &&
   capture_id==bank_capture_id[slot*64+:64] && start_seq==bank_start_seq[slot*64+:64];
 wire fields_ok=capture_id!=0 && (source_role==2 || source_role==3) &&
   (status&8'he8)==0 && requested_count!=0 && requested_count<=16384 &&
   actual_count!=0 && actual_count<=requested_count;
 wire legal=owner_ok && fields_ok && !block_new_work && !id_exhausted;
 wire [7:0] effective_status=status | ((truncated[slot] || actual_count!=requested_count)?8'h10:8'h00);
 reg [31:0] next_metadata_id;
 reg local_rejected;
 wire encoder_rejected;
 wire accepted=request_valid && request_ready && legal && !rst;
 assign capacity_available=request_ready && !block_new_work && !id_exhausted && !rst;
 assign rejected=local_rejected | encoder_rejected;
 aux_record_metadata #(.PHYSICAL_MASKS_IN_TEMPLATE(PHYSICAL_MASKS_IN_TEMPLATE)) encoder(
  .clk(clk),.rst(rst),.request_valid(request_valid&&legal),.result_ready(result_ready),.bound(1'b1),
  .template_header(template_header),.metadata_id(next_metadata_id),.epoch_id(epoch_id),
  .source_epoch(source_epoch),.h_calibration_id(h_calibration_id),.v_calibration_id(v_calibration_id),
  .config_id(config_id),.fir_id(fir_id),.capture_id(capture_id),.owner_epoch(owner_epoch),
  .generation(generation),.tx_token(tx_token),.start_seq(start_seq),.start_gsc(start_gsc),
  .sample_count(actual_count),.source_role(source_role),.status(effective_status),.bank(bank),
  .request_ready(request_ready),.result_valid(result_valid),.rejected(encoder_rejected),
  .header_data(header_data),.metadata_data(metadata_data));
 always @(posedge clk) begin
  if(rst) begin next_metadata_id<=1;id_exhausted<=(MAX_METADATA_ID==0);local_rejected<=0;reject_count<=0;end
  else begin
   local_rejected<=request_valid && request_ready && !legal;
   if(request_valid && request_ready && !legal && reject_count!=32'hffffffff)reject_count<=reject_count+1'b1;
   if(accepted)begin
    if(next_metadata_id==MAX_METADATA_ID)id_exhausted<=1;
    else next_metadata_id<=next_metadata_id+1'b1;
   end
  end
 end
endmodule
