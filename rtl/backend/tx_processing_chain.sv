// All four logical sources share routing, per-DAC calibration, interpolation
// and final zero-code mute. Source generators and RF binding remain external.
module tx_processing_chain(
 input wire clk_rf,rst,mode_request,safe_boundary,rf_permit,hard_fault,single_antenna_ota,config_commit,
 input wire [2:0] requested_mode,
 input wire [7:0] route_select,route_enable,cal_valid,
 input wire [127:0] dc_i,dc_q,input wire [143:0] gain_i,gain_q,
 input wire [31:0] config_id,
 input wire [63:0] live_data,drfm_data,dds_data,awg_data,
 input wire live_valid,drfm_valid,dds_valid,awg_valid,
 output wire [2:0] active_mode,output wire mode_accepted,mode_rejected,
 output reg config_accepted,config_rejected,output reg [31:0] active_config_id,
 output wire [127:0] calibrated_i,calibrated_q,
 output wire [7:0] calibrated_valid,calibration_saturated,tx_saturated,native_dac_valid,
 output wire [1023:0] native_dac_data
);
 reg [127:0] dc_i_hold,dc_q_hold;reg [143:0] gain_i_hold,gain_q_hold;
 reg [7:0] cal_valid_hold,enable_hold;
 wire config_allowed=safe_boundary&&(active_mode==0)&&!mode_request;
 wire load_config=config_commit&&config_allowed;
 wire [63:0] selected_data;wire selected_valid;
 wire [255:0] routed;wire [7:0] routed_valid;
 wire [511:0] interpolated_i,interpolated_q;wire [7:0] interpolated_valid;
 tx_source_mux sources(.clk(clk_rf),.rst(rst),.request(mode_request),.requested_mode(requested_mode),
  .safe_boundary(safe_boundary&&!config_commit),.rf_permit(rf_permit&&!hard_fault),.single_antenna_ota(single_antenna_ota),
  .live_data(live_data),.drfm_data(drfm_data),.dds_data(dds_data),.awg_data(awg_data),
  .live_valid(live_valid),.drfm_valid(drfm_valid),.dds_valid(dds_valid),.awg_valid(awg_valid),
  .active_mode(active_mode),.accepted(mode_accepted),.rejected(mode_rejected),.out_data(selected_data),.out_valid(selected_valid));
 tx_channel_router router(.clk(clk_rf),.rst(rst),.in_valid(selected_valid&&(active_mode!=0)),
  .route_commit(load_config),.safe_boundary(config_allowed),.shadow_select(route_select),.shadow_enable(route_enable),
  .in_hv(selected_data),.out_valid(),.commit_ack(),.commit_rejected(),.lane_valid(routed_valid),.out_lanes(routed));
 always @(posedge clk_rf)begin
  if(rst)begin
   dc_i_hold<=0;dc_q_hold<=0;gain_i_hold<=0;gain_q_hold<=0;cal_valid_hold<=0;enable_hold<=0;
   active_config_id<=0;config_accepted<=0;config_rejected<=0;
  end else begin
   config_accepted<=load_config;config_rejected<=config_commit&&!config_allowed;
   if(load_config)begin
    dc_i_hold<=dc_i;dc_q_hold<=dc_q;gain_i_hold<=gain_i;gain_q_hold<=gain_q;
    cal_valid_hold<=cal_valid;enable_hold<=route_enable;active_config_id<=config_id;
   end
  end
 end
 genvar c;
 generate for(c=0;c<8;c=c+1)begin: dac_lane
  wire cal_out_valid;wire [1:0] sat;
  tx_cal_executor correction(.clk(clk_rf),.rst(rst),.in_valid(routed_valid[c]),.cal_valid(cal_valid_hold[c]),
   .in_i(routed[c*32+:16]),.in_q(routed[c*32+16+:16]),.dc_i(dc_i_hold[c*16+:16]),.dc_q(dc_q_hold[c*16+:16]),
   .gain_i(gain_i_hold[c*18+:18]),.gain_q(gain_q_hold[c*18+:18]),
   .out_valid(cal_out_valid),.out_cal_valid(calibrated_valid[c]),.out_i(calibrated_i[c*16+:16]),.out_q(calibrated_q[c*16+:16]),.saturated(calibration_saturated[c]));
  fir_tx_lane interpolation(.clk(clk_rf),.rst(rst),.in_valid(1'b1),
   .in_i(calibrated_valid[c]?calibrated_i[c*16+:16]:16'd0),.in_q(calibrated_valid[c]?calibrated_q[c*16+:16]:16'd0),
   .out_i(interpolated_i[c*64+:64]),.out_q(interpolated_q[c*64+:64]),
   .out_valid(interpolated_valid[c]),.out_sat(sat));
  assign tx_saturated[c]=interpolated_valid[c]&&(|sat);
 end endgenerate
 dac_stream_adapter dac(.iq_i(interpolated_i),.iq_q(interpolated_q),.iq_valid(interpolated_valid),
  .enable_mask(enable_hold&cal_valid_hold),.permit(rf_permit&&!rst&&(active_mode!=0)),.fault(hard_fault),
  .native_data(native_dac_data),.native_valid(native_dac_valid));
endmodule
