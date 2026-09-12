// All sources join here before channel routing and common TX calibration.
module tx_source_mux(
 input wire clk,rst,request,input wire [2:0] requested_mode,
 input wire safe_boundary,rf_permit,single_antenna_ota,
 input wire [63:0] live_data,drfm_data,dds_data,awg_data,
 input wire live_valid,drfm_valid,dds_valid,awg_valid,
 output reg [2:0] active_mode,output reg accepted,rejected,
 output reg [63:0] out_data,output reg out_valid);
 reg pending;reg [2:0] pending_mode;
 always @(posedge clk) begin
  if(rst)begin active_mode<=0;pending<=0;pending_mode<=0;accepted<=0;rejected<=0;end
  // A mute command cancels any queued start, even without a safe boundary.
  else if(request && requested_mode==0) begin
   active_mode<=0;pending<=0;pending_mode<=0;accepted<=1;rejected<=0;
  end
  else begin
   accepted<=0;rejected<=0;
   if(pending&&safe_boundary)begin
    pending<=0;
    if(pending_mode==1&&single_antenna_ota)rejected<=1;
    else begin active_mode<=pending_mode;accepted<=1;end
   end
   if(request)begin
    if(pending||requested_mode>4||(requested_mode==1&&single_antenna_ota)) rejected<=1;
    else if(safe_boundary)begin active_mode<=requested_mode;accepted<=1;end
    else begin pending<=1;pending_mode<=requested_mode;end
   end
  end
 end
 always @* begin
  out_data=0;out_valid=1;
  if(rf_permit&&!rst)begin
   case(active_mode)
    1:if(!single_antenna_ota)begin out_valid=live_valid;if(live_valid)out_data=live_data;end
    2:begin out_valid=drfm_valid;if(drfm_valid)out_data=drfm_data;end
    3:begin out_valid=dds_valid;if(dds_valid)out_data=dds_data;end
    4:begin out_valid=awg_valid;if(awg_valid)out_data=awg_data;end
    default:begin out_data=0;out_valid=1;end
   endcase
  end
 end
endmodule
