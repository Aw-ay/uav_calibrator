`timescale 1ns/1ps
module tb_fine_accumulator;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,job_valid=0,sample_valid=0,sample_last=0,result_release=0;
 reg [14:0] job_count,sample_index;reg [63:0] sample_data;reg [1:0] body_keep;
 reg [2:0] segment_h,segment_v;reg [3:0] query_bin=0;
 wire job_ready,sample_ready,result_valid,error;
 wire signed [47:0] bin_real,bin_imag,hv_real,hv_imag;
 wire [31:0] bin_center_twice;wire [14:0] bin_count,hv_count,body_count_h,body_count_v;
 wire [45:0] bin_energy_now,bin_energy_prev,hv_energy_h,hv_energy_v,body_energy_h,body_energy_v;
 fine_segment_accumulator dut(.*);
 reg [87:0] vectors[0:19999];reg [324:0] expected[0:101],actual;
 integer count,jobs,offset=0,job,n,j,stall;string root;reg [31:0] rng=32'h71845297;
 task automatic step;begin @(negedge clk);end endtask
 task automatic launch(input integer num);begin
  wait(job_ready);step();job_count=num;job_valid=1;step();job_valid=0;
 end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count)||!$value$plusargs("JOBS=%d",jobs))$fatal(1,"args");
  $readmemh({root,"/samples.hex"},vectors,0,count-1);$readmemh({root,"/sums.hex"},expected,0,jobs*17-1);
  repeat(3)step();rst=0;
  for(job=0;job<jobs;job=job+1)begin
   n=1;while(!vectors[offset+n-1][87])n=n+1;
   launch(n);
   for(j=0;j<n;j=j+1)begin
    rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
    if(rng[2:0]==0)begin sample_valid=0;repeat(3)step();end
    if(!sample_ready)$fatal(1,"throughput stall");
    {sample_last,sample_index,segment_v,segment_h,body_keep,sample_data}=vectors[offset+j];sample_valid=1;step();
   end
   sample_valid=0;offset=offset+n;
   wait(result_valid);#1;
   if(sample_ready||job_ready)$fatal(1,"result ownership lost");
   for(j=0;j<16;j=j+1)begin
    query_bin=j;#1;actual={90'd0,bin_energy_prev,bin_energy_now,bin_count,bin_center_twice,bin_imag,bin_real};
    if(actual!==expected[job*17+j])$fatal(1,"job%0d bin%0d got%h expected%h",job,j,actual,expected[job*17+j]);
   end
   actual={body_count_v,body_count_h,body_energy_v,body_energy_h,hv_count,hv_energy_v,hv_energy_h,hv_imag,hv_real};
   if(actual!==expected[job*17+16])$fatal(1,"scalar sums job%0d",job);
   repeat(9)begin step();if(!result_valid||job_ready)$fatal(1,"held result");end
   result_release=1;step();result_release=0;
  end
  // Cancel both arithmetic stages, restart, then reject an index discontinuity.
  for(j=0;j<3;j=j+1)begin
   launch(9);sample_valid=1;sample_last=0;sample_index=0;sample_data=64'hffffffffffffffff;body_keep=3;
   step();sample_valid=0;repeat(j)step();abort=1;step();abort=0;
   repeat(5)step();if(result_valid||!job_ready)$fatal(1,"abort drain");
  end
  launch(9);sample_valid=1;sample_index=1;step();sample_valid=0;
  if(!error)$fatal(1,"index gap not rejected");repeat(5)step();if(result_valid)$fatal(1,"bad job published");
  launch(0);if(!error)$fatal(1,"zero job accepted");
  $display("PASS Fine H/V accumulator: %0d samples, %0d jobs, exact bins/energies/HV, stalls/abort",count,jobs);$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
