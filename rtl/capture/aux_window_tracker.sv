// RF-clock AUX context. Descriptor consumption never releases a RAW bank.
module aux_window_tracker #(
 parameter integer ADDR_W=14, PRE_SAMPLES=250
)(
 input wire clk,rst,block_new_work,cancel,sample_valid,aux_valid,
 input wire [63:0] sample_seq,sample_gsc,
 input wire [7:0] source_role,
 input wire [31:0] source_epoch,h_calibration_id,v_calibration_id,config_id,fir_id,
 input wire request_valid,
 output wire request_ready,
 output reg request_accepted,request_rejected,
 input wire [63:0] request_onset_seq,request_tx_token,
 input wire [31:0] request_count,
 output wire aux_trigger,
 output wire [63:0] aux_onset,aux_pulse_id,
 input wire aux_admitted,
 input wire [3:0] armed,pending,frozen,truncated,
 input wire [255:0] generation,pulse_id,start_seq,
 input wire [4*(ADDR_W+1)-1:0] sample_count,
 input wire [63:0] owner_epoch,
 output reg [3:0] eop_valid,
 output reg [255:0] eop_stop,eop_generation,
 output wire result_valid,
 input wire result_ready,
 output reg result_bound,
 output reg [7:0] result_status,
 output reg [1:0] result_bank,
 output reg [63:0] result_capture_id,result_owner_epoch,result_generation,
 output reg [63:0] result_start_seq,result_start_gsc,result_tx_token,
 output reg [14:0] result_count,
 output reg [7:0] result_source_role,
 output reg [31:0] result_source_epoch,result_h_calibration_id,result_v_calibration_id,result_config_id,result_fir_id,
 output reg [31:0] reject_count,
 output wire busy
);
 localparam [1:0] IDLE=0, WAIT_OWNER=1, TRACK=2, RESULT=3;
 localparam integer HIST_W=$clog2(PRE_SAMPLES+1)+1;
 reg [1:0] state;
 reg [HIST_W-1:0] history;
 reg [63:0] last_seq,next_id,stop_seq;
 reg exhausted;
 reg [167:0] last_context;
 reg [255:0] before_generation;
 wire [167:0] context_now={source_role,source_epoch,h_calibration_id,v_calibration_id,config_id,fir_id};
 wire [167:0] context_saved={result_source_role,result_source_epoch,result_h_calibration_id,result_v_calibration_id,result_config_id,result_fir_id};
 wire good=sample_valid && aux_valid && (source_role==2 || source_role==3);
 wire contiguous=(last_seq!=64'hffffffffffffffff && sample_seq==last_seq+1);
 wire [64:0] requested_stop={1'b0,sample_seq}+{33'd0,request_count}-PRE_SAMPLES;
 wire legal=good && history>=PRE_SAMPLES && contiguous && context_now==last_context &&
   request_onset_seq==sample_seq && sample_seq>=PRE_SAMPLES && sample_gsc>=4*PRE_SAMPLES &&
   request_count>=PRE_SAMPLES+3 && request_count<=(1<<ADDR_W) && request_count<=16384 && !requested_stop[64];
 assign request_ready=(state==IDLE && !block_new_work && !cancel && !exhausted && |armed);
 assign aux_trigger=request_valid && request_ready && legal && !rst;
 assign aux_onset=sample_seq;
 assign aux_pulse_id=next_id;
 assign result_valid=state==RESULT;
 assign busy=state!=IDLE;
 integer match_count;
 reg [1:0] candidate;
 always @* begin
   match_count=0;candidate=0;
   for(integer b=0;b<4;b=b+1)
     if(before_generation[b*64+:64]!=64'hffffffffffffffff &&
        generation[b*64+:64]==before_generation[b*64+:64]+64'd1 &&
        pulse_id[b*64+:64]==result_capture_id && !armed[b] && !frozen[b]) begin
       match_count=match_count+1;candidate=b;
     end
   eop_valid=0;eop_stop=0;eop_generation=0;
   if(state==TRACK && result_bound && owner_epoch==result_owner_epoch &&
      generation[result_bank*64+:64]==result_generation && !pending[result_bank] && !frozen[result_bank] && !armed[result_bank]) begin
     eop_valid[result_bank]=1;
     eop_stop[result_bank*64+:64]=stop_seq;
     eop_generation[result_bank*64+:64]=result_generation;
   end
 end
 reg [7:0] active_status;
 always @* begin
   active_status=result_status;
   if(cancel) active_status=active_status|8'h04;
   // Changes after the exclusive window end cannot alter captured metadata.
   if(sample_seq<stop_seq) begin
     if(context_now!=context_saved) active_status=active_status|8'h01;
     if(!good || !contiguous) active_status=active_status|8'h02;
   end
 end
 always @(posedge clk) begin
   if(rst) begin
     state<=IDLE;history<=0;last_seq<=0;last_context<=0;next_id<=1;exhausted<=0;
     stop_seq<=0;before_generation<=0;request_accepted<=0;request_rejected<=0;reject_count<=0;
     result_bound<=0;result_status<=0;result_bank<=0;result_capture_id<=0;result_owner_epoch<=0;result_generation<=0;
     result_start_seq<=0;result_start_gsc<=0;result_tx_token<=0;result_count<=0;result_source_role<=0;
     result_source_epoch<=0;result_h_calibration_id<=0;result_v_calibration_id<=0;result_config_id<=0;result_fir_id<=0;
   end else begin
     last_seq<=sample_seq;last_context<=context_now;
     if(!good) history<=0;
     else if(!contiguous || context_now!=last_context) history<=1;
     else if(history<PRE_SAMPLES) history<=history+1'b1;
     request_accepted<=aux_trigger;
     request_rejected<=request_valid && !aux_trigger;
     if(request_valid && !aux_trigger && reject_count!=32'hffffffff) reject_count<=reject_count+1'b1;
     case(state)
       IDLE: if(aux_trigger) begin
         state<=WAIT_OWNER;result_bound<=0;result_status<=0;result_bank<=0;result_generation<=0;
         result_capture_id<=next_id;
         if(next_id==64'hffffffffffffffff) exhausted<=1;else next_id<=next_id+1'b1;
         result_owner_epoch<=owner_epoch;before_generation<=generation;
         result_start_seq<=sample_seq-PRE_SAMPLES;result_start_gsc<=sample_gsc-4*PRE_SAMPLES;
         stop_seq<=requested_stop[63:0];result_count<=request_count[14:0];result_tx_token<=request_tx_token;
         result_source_role<=source_role;result_source_epoch<=source_epoch;
         result_h_calibration_id<=h_calibration_id;result_v_calibration_id<=v_calibration_id;
         result_config_id<=config_id;result_fir_id<=fir_id;
       end
       WAIT_OWNER: begin
         result_status<=active_status;
         if(!aux_admitted || match_count!=1 || owner_epoch!=result_owner_epoch) begin
           state<=RESULT;result_status<=active_status|8'h08;result_bound<=0;
         end else begin
           result_bank<=candidate;result_generation<=generation[candidate*64+:64];result_bound<=1;state<=TRACK;
         end
       end
       TRACK: begin
         result_status<=active_status;
         if(owner_epoch!=result_owner_epoch || generation[result_bank*64+:64]!=result_generation ||
            pulse_id[result_bank*64+:64]!=result_capture_id || armed[result_bank] || frozen[result_bank]) begin
           result_bound<=0;result_status<=active_status|8'h08;state<=RESULT;
         end else if(pending[result_bank]) begin
           state<=RESULT;
           if(truncated[result_bank] || start_seq[result_bank*64+:64]!=result_start_seq ||
              sample_count[result_bank*(ADDR_W+1)+:(ADDR_W+1)]!=result_count)
             result_status<=active_status|8'h10;
         end
       end
       RESULT: if(result_ready) state<=IDLE;
       default: state<=IDLE;
     endcase
   end
 end
endmodule
