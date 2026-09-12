module gsc_timebase(input wire rf_clk,rst_n,output reg [63:0] gsc);
 import calibrator_contract_pkg::*;
 always @(posedge rf_clk or negedge rst_n)
  if(!rst_n)gsc<=0;else gsc<=gsc+SYS_RATES_GSC_INCREMENT_PER_RF_CLOCK;
endmodule
