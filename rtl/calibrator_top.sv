// Reusable normalized digital RF core, clk_rf = 125 MHz. Physical lane order
// only; board clock/SYSREF, pin constraints and analog interlocks are external.
// RX quality=1 means valid and past conservative warmup/loss influence window.
// Synchronous reset/controls. This is an OOC core, not a download-ready wrapper.
module calibrator_top(
 input wire clk_rf,rst,acquisition_enable,
 input wire [1023:0] native_adc_data,
 input wire [15:0] native_adc_valid,
 output wire [15:0] native_adc_ready,
 output wire [127:0] rx_i,rx_q,
 output wire [7:0] rx_valid,rx_quality,rx_saturated,tx_saturated,
 input wire [127:0] tx_i,tx_q,
 input wire [7:0] tx_valid,tx_enable_mask,
 input wire tx_permit,tx_fault,
 output wire [1023:0] native_dac_data,
 output wire [7:0] native_dac_valid
);
 wire [511:0] adc_i,adc_q,dac_i,dac_q;
 wire [7:0] adc_pair_valid,dac_iq_valid;
 wire rx_reset=rst || !acquisition_enable;
 rfdc_stream_adapter adc(.native_data(native_adc_data),
  .native_valid(native_adc_valid),.native_ready(native_adc_ready),
  .iq_i(adc_i),.iq_q(adc_q),.iq_valid(adc_pair_valid));
 genvar c;
 generate for(c=0;c<8;c=c+1) begin: physical_lane
  wire [1:0] rx_saturation,tx_saturation;
  reg [5:0] quality_holdoff;
  // Effective RX response length = 19 + 2*(75-1) = 167 high-rate
  // samples. A missing four-SPC beat can reach output index m+42,
  // arriving at m+56 after 14 pipeline intervals. Hold through m+56;
  // quality can first recover at m+57 (57 complete subsequent beats).
  // A missing I or Q stream invalidates the entire physical complex beat.
  always @(posedge clk_rf) begin
   if(rx_reset || !adc_pair_valid[c]) quality_holdoff<=6'd57;
   else if(quality_holdoff!=0) quality_holdoff<=quality_holdoff-1'b1;
  end
  assign rx_saturated[c]=rx_valid[c] && (|rx_saturation);
  assign tx_saturated[c]=dac_iq_valid[c] && (|tx_saturation);
  assign rx_quality[c]=rx_valid[c] && (quality_holdoff==0) && !rx_saturated[c];
  fir_rx_lane rx_filter(.clk(clk_rf),.rst(rx_reset),.in_valid(1'b1),
   .in_i(adc_pair_valid[c]?adc_i[c*64+:64]:64'b0),
   .in_q(adc_pair_valid[c]?adc_q[c*64+:64]:64'b0),
   .out_i(rx_i[c*16+:16]),.out_q(rx_q[c*16+:16]),
   .out_valid(rx_valid[c]),.out_sat(rx_saturation));
  // Always advance interpolation history; sparse TX beats are zero-valued
  // samples. Pulse enable/permit never resets or pauses either FIR stage.
  fir_tx_lane tx_filter(.clk(clk_rf),.rst(rst),.in_valid(1'b1),
   .in_i(tx_valid[c]?tx_i[c*16+:16]:16'b0),
   .in_q(tx_valid[c]?tx_q[c*16+:16]:16'b0),
   .out_i(dac_i[c*64+:64]),.out_q(dac_q[c*64+:64]),
   .out_valid(dac_iq_valid[c]),.out_sat(tx_saturation));
 end endgenerate
 dac_stream_adapter dac(.iq_i(dac_i),.iq_q(dac_q),
  .iq_valid(dac_iq_valid),.enable_mask(tx_enable_mask),
  .permit(tx_permit && !rst),.fault(tx_fault),
  .native_data(native_dac_data),.native_valid(native_dac_valid));
endmodule
