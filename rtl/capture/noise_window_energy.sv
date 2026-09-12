// Apply a frozen onset noise-power snapshot to the final matched window count.
// No stationarity claim: caller must qualify noise across the capture window.
module noise_window_energy(
 input wire [191:0] noise_power,
 input wire [5:0] noise_known,
 input wire [14:0] sample_count,
 output wire [275:0] noise_energy,
 output wire [5:0] energy_known
);
 genvar c;
 generate for(c=0;c<6;c=c+1)begin: lane
  wire [31:0] p=noise_power[c*32+:32];
  wire [46:0] product={15'd0,p}*{32'd0,sample_count};
  assign energy_known[c]=noise_known[c]&&sample_count!=0&&sample_count<=16384&&p<=32'h80000000;
  assign noise_energy[c*46+:46]=energy_known[c]?product[45:0]:46'd0;
 end endgenerate
endmodule
