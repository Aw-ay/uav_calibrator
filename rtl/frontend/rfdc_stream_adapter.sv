// ZU27DR Dual ADC native format, checked against generated RFDC 2.6 rev11:
// streams m<t><0/1> = first converter I/Q; m<t><2/3> = second I/Q.
// Each native stream holds four chronological 16-bit real words, LSB first.
// Physical order only: external analog H/V/range wiring is a separate mapping.
module rfdc_stream_adapter(
 input wire [1023:0] native_data,input wire [15:0] native_valid,
 output wire [15:0] native_ready,
 output wire [511:0] iq_i,iq_q,output wire [7:0] iq_valid);
 assign native_ready=16'hffff;
 genvar c;
 generate for(c=0;c<8;c=c+1)begin: lane
  assign iq_i[c*64+:64]=native_data[(2*c)*64+:64];
  assign iq_q[c*64+:64]=native_data[(2*c+1)*64+:64];
  assign iq_valid[c]=native_valid[2*c]&native_valid[2*c+1];
 end endgenerate
endmodule
