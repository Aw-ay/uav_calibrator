`timescale 1ns/1ps
module tb_statistics_latency;
 reg clk=0; always #4 clk=~clk;
 reg rst=1,request_valid=0,result_ready=0;
 wire request_ready,result_valid; wire [7:0] result_error;
 wire [15:0] ram_read_enable; reg [15:0] ram_read_valid=0;
 wire [223:0] ram_read_address; reg [1023:0] ram_read_data=0;
 reg [239:0] counts=0; wire [511:0] stats;
 capture_statistics_reader dut(.clk(clk),.rst(rst),.request_valid(request_valid),.request_ready(request_ready),
  .request_bank_ids(6'd0),.request_generations(192'd0),.request_key(256'd0),.request_bad_channels(6'd0),
  .pending(16'h0111),.frozen(16'd0),.truncated(16'd0),.generation(1024'd0),.pulse_id(1024'd0),.start_seq(1024'd0),
  .sample_count(counts),.owner_epoch(64'd0),.abort_request(1'b0),.ram_read_enable(ram_read_enable),
  .ram_read_address(ram_read_address),.ram_read_data(ram_read_data),.ram_read_valid(ram_read_valid),
  .result_valid(result_valid),.result_ready(result_ready),.result_error(result_error),.result_stats(stats));
 // Fixed one-cycle RAM model with independent address-sensitive data.
 always @(posedge clk)begin
  ram_read_valid<=ram_read_enable;
  for(integer g=0;g<3;g=g+1)if(ram_read_enable[g*4])
   ram_read_data[g*256+:64]<={16'd0,16'd2,16'd0,16'd1};
 end
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task scan(input integer n);
 integer cycles,reads;
 begin
  counts=0;for(integer g=0;g<3;g=g+1)counts[g*60+:15]=n;
  request_valid=1;tick();request_valid=0;cycles=0;reads=0;
  while(!result_valid&&cycles<40000)begin
   if(ram_read_enable==16'h0111)reads=reads+1;
   tick();cycles=cycles+1;
  end
  if(cycles!=2*n+1||reads!=n||result_error!=0||stats[45:0]!=n||stats[138+:46]!=4*n)
   $fatal(1,"latency count=%0d cycles=%0d reads=%0d",n,cycles,reads);
  $display("SCAN samples=%0d cycles=%0d ticks=%0d",n,cycles,cycles*4);
  repeat(20)tick();if(!result_valid||ram_read_enable!=0)$fatal(1,"held result must not rescan");
  result_ready=1;tick();result_ready=0;
 end endtask
 initial begin tick();rst=0;scan(1);scan(15500);scan(16384);
  $display("PASS statistics measured latency");$finish;end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
