`timescale 1ns/1ps
module tb_native_adapters;
 reg [1023:0] adc_native=0;reg [15:0] adc_valid=0;
 wire [511:0] adc_i,adc_q;wire [7:0] iq_valid;wire [15:0] adc_ready;
 reg [511:0] tx_i=0,tx_q=0;reg [7:0] tx_valid=0,enable_mask=0;reg permit=0,fault=0;
 wire [1023:0] dac_native;wire [7:0] dac_valid;
 rfdc_stream_adapter rx(.native_data(adc_native),.native_valid(adc_valid),.native_ready(adc_ready),.iq_i(adc_i),.iq_q(adc_q),.iq_valid(iq_valid));
 dac_stream_adapter tx(.iq_i(tx_i),.iq_q(tx_q),.iq_valid(tx_valid),.enable_mask(enable_mask),.permit(permit),.fault(fault),.native_data(dac_native),.native_valid(dac_valid));
 initial begin
  for(integer c=0;c<8;c=c+1)for(integer s=0;s<4;s=s+1)begin
   adc_native[(2*c)*64+s*16+:16]=c*100+s;
   adc_native[(2*c+1)*64+s*16+:16]=16'hf000+c*100+s;
   tx_i[c*64+s*16+:16]=c*100+s;tx_q[c*64+s*16+:16]=16'hf000+c*100+s;
  end
  adc_valid=16'hffff;tx_valid=8'hff;enable_mask=8'hff;#1;
  if(adc_ready!==16'hffff||iq_valid!==8'hff)$fatal(1,"ADC must never backpressure");
  if(dac_native!==0||dac_valid!==8'hff)$fatal(1,"mute must be continuous zero samples");
  for(integer c=0;c<8;c=c+1)for(integer s=0;s<4;s=s+1)begin
   if(adc_i[c*64+s*16+:16]!==16'(c*100+s)||adc_q[c*64+s*16+:16]!==16'(16'hf000+c*100+s))$fatal(1,"ADC sample/lane mapping");
  end
  permit=1;#1;
  for(integer c=0;c<8;c=c+1)for(integer s=0;s<4;s=s+1)begin
   if(dac_native[c*128+s*32+:16]!==16'(c*100+s)||dac_native[c*128+s*32+16+:16]!==16'(16'hf000+c*100+s))$fatal(1,"DAC interleave");
  end
  adc_valid[5]=0;tx_valid[2]=0;enable_mask[5]=0;#1;
  if(iq_valid!==8'hfb||dac_native[2*128+:128]!==0||dac_native[5*128+:128]!==0||dac_valid!==8'hff)$fatal(1,"invalid paired stream or disabled lane");
  fault=1;#1;if(dac_native!==0||dac_valid!==8'hff)$fatal(1,"fault zero-code priority");
  $display("PASS native adapters: 8 lanes x4 samples, paired validity, continuous mute");$finish;
 end
endmodule
