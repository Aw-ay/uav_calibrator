// Observe source retirement only: never reports DAC/FIR-tail or RF completion.
module source_event_queue #(parameter integer ADDR_W=4)(
 input wire clk,rst,accept_valid,dds_done,awg_done,drained,time_valid,pop_valid,
 input wire [31:0] accept_source,command_sequence,config_id,cancel_reason,
 input wire [63:0] gsc,pop_token,
 output wire [31:0] count,output reg [31:0] dropped,
 output wire [63:0] head_token,output wire [319:0] head_data,output wire pop_ok
);
 import instrument_control_pkg::*;
 localparam integer DEPTH=1<<ADDR_W;
 reg active,seen_done,time_known;reg [31:0] source_hold,sequence_hold,config_hold,reason_hold;reg [63:0] accept_gsc;
 wire matching_done=(source_hold==SOURCE_DDS)?dds_done:awg_done;
 wire retire=active&&(seen_done||matching_done)&&drained;
 wire valid_source=accept_source==SOURCE_DDS||accept_source==SOURCE_AWG;
 wire accept=accept_valid&&valid_source&&(!active||retire);
 wire observation_lost=accept_valid&&!accept;
 wire [31:0] reason=(reason_hold!=SOURCE_REASON_NORMAL)?reason_hold:cancel_reason;
 wire timestamps_ok=time_known&&time_valid&&gsc>=accept_gsc;
 wire [319:0] record_data={timestamps_ok?gsc:64'd0,timestamps_ok?accept_gsc:64'd0,
  timestamps_ok?SOURCE_EVENT_TIME_VALID:32'd0,config_hold,sequence_hold,reason,source_hold,SOURCE_EVENT_TAG};
 reg [319:0] data_mem[0:DEPTH-1];reg [63:0] token_mem[0:DEPTH-1];
 reg [ADDR_W-1:0] rd,wr;reg [ADDR_W:0] occupancy;reg [63:0] next_token;reg exhausted;
 assign count={{(31-ADDR_W){1'b0}},occupancy};
 assign head_token=(!rst&&occupancy!=0)?token_mem[rd]:64'd0;
 assign head_data=(!rst&&occupancy!=0)?data_mem[rd]:320'd0;
 assign pop_ok=!rst&&pop_valid&&occupancy!=0&&pop_token==head_token;
 wire push=retire&&!exhausted&&(occupancy<DEPTH||pop_ok);
 always @(posedge clk)begin
  if(rst)begin
   active<=0;seen_done<=0;time_known<=0;source_hold<=0;sequence_hold<=0;config_hold<=0;reason_hold<=0;accept_gsc<=0;
   rd<=0;wr<=0;occupancy<=0;dropped<=0;next_token<=1;exhausted<=0;
  end else begin
   if(active)begin
    if(matching_done)seen_done<=1;
    if(reason_hold==SOURCE_REASON_NORMAL&&cancel_reason!=SOURCE_REASON_NORMAL)reason_hold<=cancel_reason;
   end
   if(retire)active<=0;
   if(accept)begin
    active<=1;seen_done<=0;time_known<=time_valid;accept_gsc<=gsc;
    source_hold<=accept_source;sequence_hold<=command_sequence;config_hold<=config_id;reason_hold<=cancel_reason;
   end
   if(push)begin
    data_mem[wr]<=record_data;token_mem[wr]<=next_token;wr<=wr+1'b1;
    if(next_token==64'hffffffffffffffff)exhausted<=1;else next_token<=next_token+1'b1;
   end
   if(((retire&&!push)||observation_lost)&&dropped!=32'hffffffff)dropped<=dropped+1'b1;
   if(pop_ok)rd<=rd+1'b1;
   case({push,pop_ok})2'b10:occupancy<=occupancy+1'b1;2'b01:occupancy<=occupancy-1'b1;default:begin end endcase
  end
 end
endmodule
