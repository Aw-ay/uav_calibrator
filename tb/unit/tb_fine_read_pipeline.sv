`timescale 1ns/1ps
// Integration scope: body membership is supplied by the test oracle. This is
// NOT an RTL edge engine. FinePass separately proves causal membership scheduling.
module tb_fine_read_pipeline;
 parameter LATENCY=1;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,start=0;reg [13:0] origin=0;reg [14:0] length=0;
 wire reader_ready,reader_busy,reader_done,reader_reject,ram_en;
 wire [12:0] ram_addr;reg [127:0] pipe[0:LATENCY-1];wire [127:0] ram_data=pipe[LATENCY-1];
 wire word_valid,word_ready,word_first,word_last;wire [127:0] word_data;
 wire [1:0] word_mask;wire [14:0] word_index;
 b_port_reader_128 #(.READ_LATENCY_B(LATENCY)) reader(.clk(clk),.rst(rst),.abort(abort),
  .desc_valid(start),.desc_ready(reader_ready),.start_ptr(origin),.sample_count(length),
  .ram_en(ram_en),.ram_addr(ram_addr),.ram_data(ram_data),.word_valid(word_valid),.word_ready(word_ready),
  .word_data(word_data),.word_mask(word_mask),.word_first(word_first),.word_last(word_last),.word_index(word_index),
  .done(reader_done),.rejected(reader_reject),.busy(reader_busy));
 wire cache_ready,sample_valid,sample_last,cache_busy,cache_done,cache_error;
 wire [63:0] sample_data;wire [14:0] sample_index;wire [5:0] occupancy;
 reg sample_enable=0;wire sample_ready=stats_ready&&sample_enable;
 reg peek_req_valid=0,peek_ready=1;reg [14:0] peek_index=0;
 wire peek_req_ready,peek_valid,peek_found;wire [63:0] peek_data;wire [14:0] peek_result_index;
 fine_sample_cache cache(.clk(clk),.rst(rst),.abort(abort),.job_valid(start),.job_ready(cache_ready),
  .job_count(length),.job_odd(origin[0]),.word_valid(word_valid),.word_ready(word_ready),.word_data(word_data),
  .word_mask(word_mask),.word_index(word_index),.word_first(word_first),.word_last(word_last),
  .sample_valid(sample_valid),.sample_ready(sample_ready),.sample_data(sample_data),.sample_index(sample_index),
  .sample_last(sample_last),.occupancy(occupancy),.busy(cache_busy),.done(cache_done),.error(cache_error),
  .peek_req_valid(peek_req_valid),.peek_req_ready(peek_req_ready),.peek_index(peek_index),
  .peek_valid(peek_valid),.peek_ready(peek_ready),.peek_found(peek_found),.peek_data(peek_data),.peek_result_index(peek_result_index));
 wire stats_job_ready,stats_ready,result_valid,error;reg result_release=0;reg [3:0] query_bin=0;
 wire signed [47:0] bin_real,bin_imag,hv_real,hv_imag;
 wire [31:0] bin_center_twice;wire [14:0] bin_count,hv_count,body_count_h,body_count_v;
 wire [45:0] bin_energy_now,bin_energy_prev,hv_energy_h,hv_energy_v,body_energy_h,body_energy_v;
 reg [87:0] vectors[0:19999];reg [324:0] expected[0:101],actual;
 integer offset=0,count,jobs,job,n,j,requests=0,retired=0,cycle=0,peak=0;
 reg checking=0;reg [31:0] rng=32'h719532ad;string root;
 wire [87:0] oracle=vectors[offset+sample_index];
 fine_segment_accumulator stats(.clk(clk),.rst(rst),.abort(abort),.job_valid(start),.job_ready(stats_job_ready),.job_count(length),
  .sample_valid(sample_valid&&sample_enable),.sample_ready(stats_ready),.sample_data(sample_data),.sample_index(sample_index),
  .sample_last(sample_last),.body_keep(oracle[65:64]),.segment_h(oracle[68:66]),.segment_v(oracle[71:69]),
  .result_valid(result_valid),.result_release(result_release),.error(error),.query_bin(query_bin),
  .bin_real(bin_real),.bin_imag(bin_imag),.bin_center_twice(bin_center_twice),.bin_count(bin_count),
  .bin_energy_now(bin_energy_now),.bin_energy_prev(bin_energy_prev),.hv_real(hv_real),.hv_imag(hv_imag),
  .hv_energy_h(hv_energy_h),.hv_energy_v(hv_energy_v),.hv_count(hv_count),
  .body_energy_h(body_energy_h),.body_energy_v(body_energy_v),.body_count_h(body_count_h),.body_count_v(body_count_v));
 function automatic [63:0] at_address(input integer physical);
  integer logical_index;
  begin logical_index=(physical-origin)&16383;
   at_address=logical_index<length?vectors[offset+logical_index][63:0]:64'hbadbadbadbadbadb;
  end
 endfunction
 always @(posedge clk)begin
  if(ram_en)pipe[0]<={at_address(2*ram_addr+1),at_address(2*ram_addr)};
  for(integer k=1;k<LATENCY;k=k+1)pipe[k]<=pipe[k-1];
  if(checking&&!abort)begin
   if(reader_reject||cache_error||error)$fatal(1,"unexpected rejection");
   if(ram_en)begin
    if(ram_addr!==((origin/2+requests)&8191))$fatal(1,"extra pass/address");
    requests=requests+1;
   end
   if(sample_valid&&sample_ready)begin
    if(sample_index!=retired||sample_data!==vectors[offset+retired][63:0])$fatal(1,"sample order");
    retired=retired+1;
   end
   if(peek_valid&&peek_found&&peek_data!==vectors[offset+peek_result_index][63:0])$fatal(1,"peek corruption");
   if(occupancy>peak)peak=occupancy;
   if(occupancy>32)$fatal(1,"overflow");
  end
 end
 always @(negedge clk)begin
  cycle=cycle+1;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  sample_enable=checking&&(cycle%197>=77)&&rng[0];
  peek_req_valid=checking&&rng[1];peek_index=sample_index+5;peek_ready=rng[2];
 end
 task automatic step;begin @(negedge clk);#0.1;end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count)||!$value$plusargs("JOBS=%d",jobs))$fatal(1,"args");
  $readmemh({root,"/samples.hex"},vectors,0,count-1);$readmemh({root,"/sums.hex"},expected,0,jobs*17-1);
  repeat(3)step();rst=0;
  for(job=0;job<jobs;job=job+1)begin
   n=1;while(!vectors[offset+n-1][87])n=n+1;
   wait(reader_ready&&cache_ready&&stats_job_ready);step();origin=job%2?16383:0;length=n;start=1;
   requests=0;retired=0;peak=0;checking=1;step();start=0;
   wait(result_valid);#1;
   if(reader_busy||retired!=n||requests!=(n+origin%2+1)/2)$fatal(1,"single-pass count/drain");
   if(n>64&&peak!=32)$fatal(1,"full-cache stall not exercised");
   for(j=0;j<16;j=j+1)begin
    query_bin=j;#1;actual={90'd0,bin_energy_prev,bin_energy_now,bin_count,bin_center_twice,bin_imag,bin_real};
    if(actual!==expected[job*17+j])$fatal(1,"bin sums");
   end
   actual={body_count_v,body_count_h,body_energy_v,body_energy_h,hv_count,hv_energy_v,hv_energy_h,hv_imag,hv_real};
   if(actual!==expected[job*17+16])$fatal(1,"scalar sums");
   checking=0;step();result_release=1;step();result_release=0;
   wait(!peek_valid);offset=offset+n;
  end
  // Local abort does not authorize reuse until outstanding B responses drain.
  offset=0;length=33;origin=1;
  for(j=0;j<40;j=j+1)begin
   wait(reader_ready&&cache_ready&&stats_job_ready);step();start=1;step();start=0;
   repeat(j)step();abort=1;#0.1;
   if(ram_en||sample_valid)$fatal(1,"activity during abort");
   step();abort=0;wait(reader_done);#1;
   if(reader_busy||reader.pending!=0||cache_busy||peek_valid||result_valid)$fatal(1,"early bank return");
  end
  $display("PASS Fine read/cache/accumulator LATENCY=%0d: single pass, odd full window=8193 requests, stalls, abort drain",LATENCY);$finish;
 end
 initial begin #5000000;$fatal(1,"timeout");end
endmodule
