// Paired ADC3/7 logical source selection only; no ADC/FIR enable/reset outputs.
module aux_source_controller #(
 parameter integer PL_FLUSH_SAMPLES_MIN=42
)(
 input wire clk_rf,rst_n,binding_valid,timing_valid,safe_to_switch,commit,
 input wire [1:0] source_shadow,
 input wire source_ack,input wire [1:0] source_feedback,input wire sample_tick,
 input wire [31:0] settling_cycles,flush_samples,switch_timeout_cycles,
 output reg [1:0] source_request,source_active,
 output wire busy,output wire aux_valid,output reg rejected,done,
 output wire unbound,output reg [31:0] source_epoch,drop_count
);
 localparam IDLE=0,WAIT_ACK=1,SETTLE=2,FLUSH=3;
 reg [1:0] state;
 reg qualified;
 reg [31:0] count;
 reg [31:0] settle_latched,flush_latched,timeout_latched;
 wire settings_ok=timing_valid && flush_samples>=42 && flush_samples>=PL_FLUSH_SAMPLES_MIN && switch_timeout_cycles!=0;
 assign busy=state!=IDLE;
 assign unbound=!binding_valid;
 assign aux_valid=qualified && binding_valid && timing_valid;
 always @(posedge clk_rf or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;source_request<=0;source_active<=0;qualified<=0;rejected<=0;done<=0;
   source_epoch<=0;drop_count<=0;count<=0;settle_latched<=0;flush_latched<=0;timeout_latched<=0;
  end else begin
   rejected<=0;done<=0;
   if(sample_tick && !aux_valid && drop_count!=32'hffffffff) drop_count<=drop_count+1;
   if(!binding_valid || !timing_valid) begin
    if(busy || commit) rejected<=1;
    state<=IDLE;qualified<=0;source_request<=0;count<=0;
   end else begin
    if(commit) begin
     if(busy || !safe_to_switch || source_shadow>2 || !settings_ok) rejected<=1;
     else begin
      source_request<=source_shadow;source_epoch<=source_epoch+1;qualified<=0;state<=WAIT_ACK;count<=0;
      settle_latched<=settling_cycles;flush_latched<=flush_samples;timeout_latched<=switch_timeout_cycles;
     end
    end
    case(state)
     WAIT_ACK: begin
      if(source_ack && source_feedback==source_request) begin
       source_active<=source_feedback;count<=0;state<=settle_latched==0?FLUSH:SETTLE;
      end else if(count>=timeout_latched-1) begin state<=IDLE;rejected<=1;count<=0;end
      else count<=count+1;
     end
     SETTLE: if(count>=settle_latched-1) begin state<=FLUSH;count<=0;end else count<=count+1;
     FLUSH: if(sample_tick) begin
      if(count>=flush_latched-1) begin state<=IDLE;qualified<=source_active!=0;done<=1;count<=0;end
      else count<=count+1;
     end
     default: begin end
    endcase
   end
  end
 end
endmodule


