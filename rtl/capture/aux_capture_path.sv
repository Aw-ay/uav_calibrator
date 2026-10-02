// Group4 independent RAW measurement. One reserved metadata slot per window;
// neither metadata POP nor descriptor acceptance returns a RAW bank.
module aux_capture_path #(parameter integer PRE_SAMPLES=250,PHYSICAL_MASKS_IN_TEMPLATE=0)(
 input wire clk,rst,block_new_work,sample_valid,input wire [63:0] sample_seq,
 input wire aux_request_valid,aux_qualified,aux_meta_pop,
 input wire [31:0] aux_request_count,input wire [63:0] aux_request_tx_token,aux_sample_gsc,aux_meta_pop_key,
 input wire [127:0] aux_context,input wire [1023:0] aux_template_header,
 output wire aux_request_ready,aux_request_accepted,aux_request_rejected,aux_meta_valid,aux_meta_pop_ok,aux_busy,aux_drain_busy,
 output wire [767:0] aux_meta_data,
 input wire [3:0] armed,pending,frozen,truncated,input wire [255:0] generation,pulse_id,start_seq,
 input wire [59:0] sample_count,input wire [63:0] owner_epoch,
 output wire aux_trigger,output wire [63:0] aux_onset,aux_pulse_id,input wire aux_admitted,
 output wire [3:0] eop_valid,output wire [255:0] eop_stop,eop_generation,
 output reg [3:0] stats_valid,publish,output wire [255:0] stats_generation,
 output wire desc_valid,output wire [1023:0] desc_header,output wire [1:0] desc_bank,
 output wire [63:0] desc_epoch,desc_generation,input wire desc_ready,stale_descriptor
);
 import calibrator_contract_pkg::*;
 wire tracker_ready,tracker_rejected,tracker_busy,window_valid,window_ready,bound;
 wire [7:0] status,role;wire [1:0] bank;wire [14:0] count;
 wire [63:0] capture,epoch,gen,first_seq,first_gsc,token;
 wire [31:0] source_epoch,hcal,vcal,config_id,fir_id;
 wire record_valid,record_ready,admit_ready,admit_rejected,capacity;
 reg meta_consumed,descriptor_consumed;reg [2:0] state;
 reg [1023:0] template_hold;
 localparam IDLE=0,STATS=1,PUBLISH=2,DESCRIPTOR=3,RETIRE=4;
 wire slot_free=state==IDLE&&!record_valid&&!tracker_busy&&capacity;
 assign aux_request_ready=slot_free&&tracker_ready;
 reg capacity_rejected;
 assign aux_request_rejected=tracker_rejected||capacity_rejected;
 assign aux_busy=tracker_busy||record_valid||state!=IDLE;
 assign aux_drain_busy=tracker_busy||(record_valid&&!descriptor_consumed);
 assign aux_meta_valid=record_valid&&!meta_consumed;
 assign aux_meta_pop_ok=aux_meta_pop&&aux_meta_valid&&aux_meta_pop_key==aux_meta_data[64+:64];
 assign window_ready=admit_ready;
 assign record_ready=record_valid&&meta_consumed&&descriptor_consumed;
 assign desc_epoch=aux_meta_data[24*8+:64];assign desc_generation=aux_meta_data[32*8+:64];
 assign desc_bank=aux_meta_data[89*8+:2];
 wire owner_ok=owner_epoch==desc_epoch&&generation[desc_bank*64+:64]==desc_generation;
 assign desc_valid=state==DESCRIPTOR&&record_valid&&owner_ok&&frozen[desc_bank];
 assign stats_generation={4{desc_generation}};
 always @*begin
  stats_valid=0;publish=0;
  if(record_valid&&owner_ok)begin
   if(state==STATS)stats_valid[desc_bank]=1;
   if(state==PUBLISH)publish[desc_bank]=1;
  end
 end
 always @(posedge clk)begin
  if(rst)begin state<=IDLE;meta_consumed<=0;descriptor_consumed<=0;capacity_rejected<=0;template_hold<=0;end
  else begin
   capacity_rejected<=aux_request_valid&&!slot_free;
   // Freeze on the actual combinational trigger, before the producer may alter its template.
   if(aux_trigger)template_hold<=aux_template_header;
   if(aux_meta_pop_ok)meta_consumed<=1;
   case(state)
    IDLE:if(record_valid)state<=STATS;
    STATS:state<=PUBLISH;
    PUBLISH:state<=DESCRIPTOR;
    DESCRIPTOR:if(!owner_ok||(desc_valid&&(desc_ready||stale_descriptor)))begin descriptor_consumed<=1;state<=RETIRE;end
    RETIRE:if(record_ready)begin state<=IDLE;meta_consumed<=0;descriptor_consumed<=0;end
    default:state<=IDLE;
   endcase
  end
 end
 aux_window_tracker #(.PRE_SAMPLES(PRE_SAMPLES)) tracker(
  .clk(clk),.rst(rst),.block_new_work(block_new_work),.cancel(block_new_work),.sample_valid(sample_valid),.aux_valid(aux_qualified),
  .sample_seq(sample_seq),.sample_gsc(aux_sample_gsc),.source_role(aux_context[7:0]),.source_epoch(aux_context[63:32]),
  .h_calibration_id(aux_context[95:64]),.v_calibration_id(aux_context[127:96]),
  .config_id(aux_template_header[FRAME_CONFIG_ID_OFFSET*8+:32]),.fir_id(aux_template_header[FRAME_FIR_ID_OFFSET*8+:32]),
  .request_valid(aux_request_valid&&slot_free),.request_ready(tracker_ready),.request_accepted(aux_request_accepted),.request_rejected(tracker_rejected),
  .request_onset_seq(sample_seq),.request_tx_token(aux_request_tx_token),.request_count(aux_request_count),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(aux_pulse_id),.aux_admitted(aux_admitted),
  .armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.generation(generation),.pulse_id(pulse_id),.start_seq(start_seq),.sample_count(sample_count),.owner_epoch(owner_epoch),
  .eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),.result_valid(window_valid),.result_ready(window_ready),
  .result_bound(bound),.result_status(status),.result_bank(bank),.result_capture_id(capture),.result_owner_epoch(epoch),.result_generation(gen),
  .result_start_seq(first_seq),.result_start_gsc(first_gsc),.result_tx_token(token),.result_count(count),.result_source_role(role),
  .result_source_epoch(source_epoch),.result_h_calibration_id(hcal),.result_v_calibration_id(vcal),.result_config_id(config_id),.result_fir_id(fir_id),.busy(tracker_busy),.reject_count());
 aux_record_admission #(.PHYSICAL_MASKS_IN_TEMPLATE(PHYSICAL_MASKS_IN_TEMPLATE)) adapter(.clk(clk),.rst(rst),.request_valid(window_valid),.result_ready(record_ready),.bound(bound),.block_new_work(1'b0),
  .template_header(template_hold),.epoch_id(template_hold[FRAME_EPOCH_ID_OFFSET*8+:32]),.source_epoch(source_epoch),.h_calibration_id(hcal),.v_calibration_id(vcal),.config_id(config_id),.fir_id(fir_id),
  .capture_id(capture),.owner_epoch(epoch),.generation(gen),.tx_token(token),.start_seq(first_seq),.start_gsc(first_gsc),.requested_count(count),.source_role(role),.status(status),.bank({2'd0,bank}),
  .live_owner_epoch(owner_epoch),.pending(pending),.frozen(frozen),.truncated(truncated),.bank_generation(generation),.bank_capture_id(pulse_id),.bank_start_seq(start_seq),.bank_sample_count(sample_count),
  .request_ready(admit_ready),.result_valid(record_valid),.rejected(admit_rejected),.capacity_available(capacity),.id_exhausted(),.reject_count(),.header_data(desc_header),.metadata_data(aux_meta_data));
endmodule
