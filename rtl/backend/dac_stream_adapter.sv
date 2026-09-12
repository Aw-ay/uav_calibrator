// DAC data is {Q3,I3,Q2,I2,Q1,I1,Q0,I0}; continuously drive zero on mute.
// permit/fault and inputs are synchronous to the DAC AXIS clock at this boundary.
// Physical RF PA/switch interlocking is additional board circuitry.
module dac_stream_adapter(
 input wire [511:0] iq_i,iq_q,input wire [7:0] iq_valid,enable_mask,
 input wire permit,fault,
 output wire [1023:0] native_data,output wire [7:0] native_valid);
 assign native_valid=8'hff;
 genvar c,s;
 generate for(c=0;c<8;c=c+1)begin: lane
  for(s=0;s<4;s=s+1)begin: sample_word
   assign native_data[c*128+s*32+:32]=(permit&&!fault&&enable_mask[c]&&iq_valid[c])?
    {iq_q[c*64+s*16+:16],iq_i[c*64+s*16+:16]}:32'b0;
  end
 end endgenerate
endmodule
