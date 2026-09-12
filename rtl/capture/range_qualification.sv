// Combinational evaluator of one immutable, aligned six-channel snapshot.
// noise_energy is expected noise energy over THE SAME sample window, not
// a per-sample noise power. SNR is excess-signal/noise, linear unsigned Q16.
// Analog linearity and calibrated gain ordering must be supplied with validity.
module range_qualification(
 input wire [275:0] energy,noise_energy,
 input wire [31:0] min_snr_q16,
 input wire [5:0] bad_channels,cal_valid,noise_valid,linearity_known,linearity_pass,
 input wire context_valid,threshold_valid,rank_valid,
 input wire [2:0] frozen_stats_done,
 input wire [5:0] gain_order,
 input wire [14:0] sample_count,
 output wire [5:0] qualified,
 output wire [47:0] reasons,
 output wire selected_valid,
 output wire [1:0] selected_range
);
 wire context_ok=context_valid&&sample_count!=0&&sample_count<=15'd16384;
 wire [32:0] required_ratio={1'b0,min_snr_q16}+33'd65536;
 genvar c;
 generate for(c=0;c<6;c=c+1)begin: channel
  wire [45:0] e=energy[c*46+:46],n=noise_energy[c*46+:46];
  wire [78:0] required_energy={46'd0,required_ratio}*{33'd0,n};
  wire snr_ok={17'd0,e,16'd0}>=required_energy;
  assign reasons[c*8+:8]={1'b0,!linearity_pass[c],!linearity_known[c],
    !snr_ok,(!noise_valid[c]||n==0||!threshold_valid),!cal_valid[c],bad_channels[c],!context_ok};
  assign qualified[c]=~(|reasons[c*8+:8]);
 end endgenerate
 capture_range_select select_range(.rank_valid(rank_valid),.gain_order(gain_order),
  .h_valid(qualified[2:0]),.v_valid(qualified[5:3]),.context_valid({3{context_ok}}),
  .frozen_stats_done(frozen_stats_done),.selected_valid(selected_valid),.selected_range(selected_range));
endmodule
