// RF-domain qualifier for the actual HB19/FIR75 receive chain. No ADC/FIR
// clock, reset or enable outputs: the six primary channels keep running.
module aux_receive_guard(
 input wire clk_rf,rst_n,binding_valid,timing_valid,safe_to_switch,commit,source_ack,
 input wire [1:0] source_shadow,source_feedback,calibration_valid,
 input wire [31:0] h_calibration_shadow,v_calibration_shadow,
 input wire [31:0] settling_cycles,flush_samples,switch_timeout_cycles,
 input wire sample_valid,sample_good,input wire [63:0] sample_data,sample_seq,sample_gsc,
 output wire [1:0] source_request,source_active,
 output wire busy,aux_valid,rejected,done,unbound,
 output wire [31:0] source_epoch,output reg [31:0] drop_count,h_calibration_id,v_calibration_id,
 output wire [7:0] source_role,output wire [63:0] aux_data,aux_seq,aux_gsc
);
 // ceil(((HB19-1)+2*(FIR75-1))/4) + 15 pipeline clocks + 1 boundary.
 // Revalidate this floor when changing the fixed RX filter architecture.
 localparam integer RX_FLUSH_MIN=58;
 wire source_qualified,control_rejected;
 reg local_rejected,feedback_lost,ack_observed;
 wire calibration_ok=(source_shadow==0)||(&calibration_valid);
 wire identity_available=!( &source_epoch );
 wire commit_forward=commit&&calibration_ok&&identity_available;
 wire accepted=commit_forward&&!busy&&binding_valid&&timing_valid&&safe_to_switch&&
               source_shadow<=2&&flush_samples>=RX_FLUSH_MIN&&switch_timeout_cycles!=0;
 aux_source_controller #(.PL_FLUSH_SAMPLES_MIN(RX_FLUSH_MIN)) controller(
  .clk_rf(clk_rf),.rst_n(rst_n),.binding_valid(binding_valid),.timing_valid(timing_valid),
  .safe_to_switch(safe_to_switch),.commit(commit_forward),.source_shadow(source_shadow),
  .source_ack(source_ack),.source_feedback(source_feedback),.sample_tick(sample_valid),
  .settling_cycles(settling_cycles),.flush_samples(flush_samples),.switch_timeout_cycles(switch_timeout_cycles),
  .source_request(source_request),.source_active(source_active),.busy(busy),.aux_valid(source_qualified),
  .rejected(control_rejected),.done(done),.unbound(unbound),.source_epoch(source_epoch),.drop_count());
 assign rejected=local_rejected||control_rejected;
 assign aux_valid=rst_n&&source_qualified&&!feedback_lost&&source_feedback==source_active&&
                  (&calibration_valid)&&sample_valid&&sample_good;
 assign source_role=!aux_valid?8'd0:(source_active==1?8'd2:8'd3);
 assign aux_data=sample_data;assign aux_seq=sample_seq;assign aux_gsc=sample_gsc;
 always @(posedge clk_rf or negedge rst_n)begin
  if(!rst_n)begin feedback_lost<=0;ack_observed<=0;local_rejected<=0;drop_count<=0;h_calibration_id<=0;v_calibration_id<=0;end
  else begin
   local_rejected<=commit&&(!calibration_ok||!identity_available);
   if(sample_valid&&!aux_valid&&drop_count!=32'hffffffff)drop_count<=drop_count+1'b1;
   // Returning feedback alone cannot requalify data containing a transient.
   if(busy&&source_ack&&source_feedback==source_request)ack_observed<=1;
   if(ack_observed&&source_feedback!=source_active)feedback_lost<=1;
   if(accepted)begin
    feedback_lost<=0;ack_observed<=0;h_calibration_id<=h_calibration_shadow;v_calibration_id<=v_calibration_shadow;
   end
  end
 end
endmodule
