`timescale 1ns/1ps
module tb_fine_finalize;
 parameter FAST_MATH=0;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,job_valid=0,result_ready=0;
 reg [3759:0] bin_data;reg [91:0] body_energy;reg [29:0] body_count;
 reg signed [47:0] hv_real,hv_imag;reg [45:0] hv_energy_h,hv_energy_v;reg [14:0] hv_count;
 reg [63:0] noise;reg [1:0] timing_valid;
 wire job_ready,result_valid;wire [63:0] mean_power,snr_q16,frequency_hz;wire [127:0] chirp_hz_per_s;
 wire [31:0] hv_phase_q31;wire [1:0] snr_saturated;wire [2:0] valid_mask;wire [23:0] quality;
 fine_finalize #(.FAST_MATH(FAST_MATH)) dut(.*);
 reg [4531:0] vectors[0:63];reg [380:0] wanted,actual;
 integer n,i,t,max_cycles=0;string root;
 task automatic step;begin @(negedge clk);end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",n))$fatal(1,"args");
  $readmemh({root,"/finalize.hex"},vectors,0,n-1);repeat(3)step();rst=0;
  for(i=0;i<n;i=i+1)begin
   wait(job_ready);step();{wanted,timing_valid,noise,hv_count,hv_energy_v,hv_energy_h,hv_imag,hv_real,body_count,body_energy,bin_data}=vectors[i];job_valid=1;
   step();job_valid=0;t=0;while(!result_valid)begin step();t=t+1;if(t>1000000)$fatal(1,"timeout state%0d",dut.state);end
   if(t>max_cycles)max_cycles=t;
   actual={hv_phase_q31,chirp_hz_per_s,frequency_hz,quality,valid_mask,snr_saturated,snr_q16,mean_power};
   if(actual!==wanted)$fatal(1,"finalize%0d got%h expected%h",i,actual,wanted);
   repeat(5)begin step();if(!result_valid||job_ready||actual!=={hv_phase_q31,chirp_hz_per_s,frequency_hz,quality,valid_mask,snr_saturated,snr_q16,mean_power})$fatal(1,"held result");end
   result_ready=1;step();result_ready=0;
  end
  $display("PASS Fine finalize %0d cases max cycles %0d: mean/SNR/signed frequency/chirp/HV/quality",n,max_cycles);$finish;
 end
endmodule
