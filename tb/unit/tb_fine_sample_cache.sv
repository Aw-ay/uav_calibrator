`timescale 1ns/1ps
module tb_fine_sample_cache;
 reg clk=0;always #2.5 clk=~clk;
 reg rst,abort,job_valid,job_odd,word_valid,word_first,word_last,sample_ready,peek_req_valid,peek_ready;
 reg [14:0] job_count,word_index,peek_index;reg [127:0] word_data;reg [1:0] word_mask;
 wire job_ready,word_ready,sample_valid,sample_last,busy,done,error,peek_req_ready,peek_valid,peek_found;
 wire [63:0] sample_data,peek_data;wire [14:0] sample_index,peek_result_index;wire [5:0] occupancy;
 fine_sample_cache dut(.*);
 localparam IW=185,OW=189;
 reg [IW+OW-1:0] vectors[0:199999];reg [OW-1:0] expected,actual;
 integer count,i;string root;
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("COUNT=%d",count))$fatal(1,"args");
  $readmemh({root,"/cache.hex"},vectors,0,count-1);
  // Establish reset before the model's first observable pre-edge state.
  rst=1;abort=0;job_valid=0;word_valid=0;peek_req_valid=0;peek_ready=0;sample_ready=0;
  @(posedge clk);#1;
  for(i=0;i<count;i=i+1)begin
   @(negedge clk);
   {expected,peek_ready,peek_index,peek_req_valid,sample_ready,word_last,word_first,
     word_index,word_mask,word_data,word_valid,job_odd,job_count,job_valid,abort,rst}=vectors[i];
   #1;
   actual={peek_result_index,peek_data,peek_found,peek_valid,peek_req_ready,error,done,busy,
           occupancy,sample_last,sample_index,sample_data,sample_valid,word_ready,job_ready};
   if(actual!==expected)$fatal(1,"cycle %0d got=%h expected=%h",i,actual,expected);
   @(posedge clk);#1;
  end
  $display("PASS Fine sample cache: %0d cycle comparisons",count);$finish;
 end
endmodule
