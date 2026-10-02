`timescale 1ns/1ps
module tb_fine_engine;
 parameter LATENCY=1;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,abort=0,job_valid=0,result_ready=0;
 wire job_ready,result_valid,busy,done,error,ram_en;wire [12:0] ram_addr;wire [1023:0] result_data;
 reg [1799:0] jobs[0:31];reg [63:0] samples[0:40000];reg [1799:0] row;
 reg [127:0] pipe[0:LATENCY-1];integer profile[0:31];integer offset,length,origin,requests=0,j,n,count,total,cycles,maxcycles=0;string root;reg checking=0;
 fine_engine #(.READ_LATENCY_B(LATENCY)) dut(.clk(clk),.rst(rst),.abort(abort),.job_valid(job_valid),.job_ready(job_ready),
  .start_ptr(row[60:47]),.sample_count(row[46:32]),.coarse_start(row[75:61]),.coarse_end(row[90:76]),
  .noise(row[154:91]),.top_signal(row[218:155]),.peak_power(row[282:219]),.source_good(row[284:283]),.noise_known(row[286:285]),
  .job_header(row[670:287]),.ram_en(ram_en),.ram_addr(ram_addr),.ram_data(pipe[LATENCY-1]),
  .result_valid(result_valid),.result_ready(result_ready),.result_data(result_data),.busy(busy),.done(done),.error(error));
 function automatic [63:0] at_address(input integer a);integer k;begin k=(a-origin)&16383;at_address=k<length?samples[offset+k]:64'hbadbadbadbadbadb;end endfunction
 always @(posedge clk)begin
  if(ram_en)begin
   pipe[0]<={at_address(2*ram_addr+1),at_address(2*ram_addr)};
   if(checking)begin if(ram_addr!==((origin/2+requests)&8191))$fatal(1,"second pass/address");requests=requests+1;end
  end
  for(integer k=1;k<LATENCY;k=k+1)pipe[k]<=pipe[k-1];
  if(checking&&dut.occupancy>32)$fatal(1,"cache capacity");
  if(checking&&dut.sample_valid&&dut.sample_ready)begin
   if(dut.sample_data[63:0]!==samples[offset+dut.sample_index])$fatal(1,"retired low IQ");
   if(dut.lane_count==2&&dut.sample_data[127:64]!==samples[offset+dut.sample_index+1])$fatal(1,"retired high IQ");
  end
  if(checking&&error)$fatal(1,"engine error job=%0d state=%0d",j,dut.state);
 end
 task automatic step;begin @(negedge clk);#0.1;end endtask
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count)||!$value$plusargs("JOBS=%d",total))$fatal(1,"args");
  $readmemh({root,"/jobs.hex"},jobs,0,total-1);$readmemh({root,"/samples.hex"},samples,0,count-1);
  repeat(3)step();rst=0;
  for(j=0;j<total;j=j+1)begin
   wait(job_ready);step();row=jobs[j];offset=row[31:0];length=row[46:32];origin=row[60:47];requests=0;checking=1;for(integer st=0;st<32;st=st+1)profile[st]=0;job_valid=1;step();job_valid=0;cycles=0;
   while(!result_valid)begin step();cycles=cycles+1;profile[dut.state]=profile[dut.state]+1;if(cycles>2000000)$fatal(1,"timeout state=%0d processed=%0d k=%0d received=%0d base=%0d",dut.state,dut.processed,dut.k,dut.received,dut.sample_index);end
   if(result_data!==row[1694:671])begin
    $display("actual=%0256h expected=%0256h",result_data,row[1694:671]);
    $fatal(1,"result job=%0d",j);
   end
   if(length==16384)begin $display("PROFILE full cycles=%0d",cycles);for(integer st=0;st<32;st=st+1)if(profile[st])$display("STATE %0d %0d",st,profile[st]);end
   if(requests!=(length+origin%2+1)/2||dut.reader_busy)$fatal(1,"single-pass drain count");
   repeat(9)begin step();if(!result_valid||result_data!==row[1694:671]||job_ready)$fatal(1,"held result");end
   result_ready=1;step();result_ready=0;checking=0;if(cycles>maxcycles)maxcycles=cycles;
  end
  // Cancel at cache fill, edge arithmetic, finalizer and held result. Drain the real RAM latency.
  row=jobs[11];offset=row[31:0];length=row[46:32];origin=row[60:47];
  for(n=0;n<4;n=n+1)begin
   wait(job_ready);step();job_valid=1;step();job_valid=0;
   case(n) 0:repeat(7)step();1:wait(dut.state==12);2:wait(dut.state==23);3:wait(result_valid);endcase
   step();abort=1;#0.1;if(ram_en)$fatal(1,"request during abort");step();abort=0;
   while(busy)step();if(dut.reader_busy||dut.reader.pending!=0||result_valid)$fatal(1,"early bank return");
   repeat(5)begin step();if(result_valid)$fatal(1,"ghost result");end
  end
  // Illegal geometry must not read memory.
  row[46:32]=0;step();job_valid=1;step();job_valid=0;
  if(!error||busy||ram_en)$fatal(1,"bad descriptor");
  $display("PASS Fine complete single-pass engine LATENCY=%0d jobs=%0d max_cycles=%0d: exact 128-byte records, odd wrap, invalids, abort/drain, held result",LATENCY,total,maxcycles);$finish;
 end
 initial begin #500000000;$fatal(1,"global timeout");end
endmodule
