`timescale 1ns/1ps
module tb_range_statistics;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,start=0,sample_enable=0,finish=0,result_ready=0;
 reg [63:0] pulse_id=0;reg [95:0] iq_i=0,iq_q=0;
 reg [5:0] sample_good=63,late_bad=0;
 wire ready,busy,result_valid,rejected;
 wire [63:0] result_id;
 wire [191:0] peak_power;wire [275:0] energy;
 wire [14:0] sample_count;wire [5:0] bad_channels;wire overflow;
 pulse_range_statistics dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 initial begin
 tick();rst=0;start=1;pulse_id=77;tick();start=0;
 check(busy&&!ready,"start ownership");
 for(integer n=1;n<=4;n=n+1) begin
  for(integer c=0;c<6;c=c+1) begin iq_i[c*16+:16]=n*(c+1);iq_q[c*16+:16]=-n*(c+1);end
  sample_enable=1;tick();
 end
 sample_enable=0;late_bad=6'b100001;finish=1;tick();finish=0;late_bad=0;
 check(result_valid&&result_id==77&&sample_count==4&&!overflow,"result identity/count");
 check(bad_channels==6'b100001,"late quality included");
 for(integer c=0;c<6;c=c+1) begin
  check(peak_power[c*32+:32]==32*(c+1)*(c+1),"peak oracle");
  check(energy[c*46+:46]==60*(c+1)*(c+1),"energy oracle");
 end
 start=1;pulse_id=99;tick();check(rejected&&result_id==77&&result_valid,"pending result cannot overwrite");start=0;
 repeat(5)tick();check(result_id==77&&sample_count==4,"result stable under stall");
 result_ready=1;tick();result_ready=0;start=1;tick();start=0;
 iq_i={6{16'h8000}};iq_q={6{16'h8000}};sample_enable=1;
 repeat(16384)tick();sample_enable=0;finish=1;tick();finish=0;
 check(result_valid&&sample_count==16384&&!overflow,"full window exact count");
 for(integer c=0;c<6;c=c+1) begin
  check(peak_power[c*32+:32]==32'h80000000,"signed square maximum");
  check(energy[c*46+:46]==46'd35184372088832,"maximum exact energy");
 end
 result_ready=1;tick();result_ready=0;start=1;tick();start=0;sample_enable=1;
 repeat(16385)tick();sample_enable=0;finish=1;tick();finish=0;
 check(overflow&&sample_count==16384&&bad_channels==63,"capacity rejects extra sample without wrap");
 rst=1;tick();rst=0;check(ready&&!result_valid&&!busy,"reset clears ownership");
 start=1;tick();start=0;finish=1;tick();finish=0;
 check(result_valid&&sample_count==0&&bad_channels==63,"empty window invalid");
 result_ready=1;tick();result_ready=0;start=1;tick();start=0;
 sample_enable=1;finish=1;sample_good=6'b111101;late_bad=6'b010000;
 iq_i={6{16'd3}};iq_q={6{16'hfffc}};tick();sample_enable=0;finish=0;
 check(sample_count==1&&bad_channels==6'b010010,"final sample and late flags same edge");
 for(integer c=0;c<6;c=c+1)check(energy[c*46+:46]==25&&peak_power[c*32+:32]==25,"singleton energy");
 result_ready=1;tick();result_ready=0;start=1;tick();start=0;rst=1;tick();rst=0;
 check(ready&&!busy&&!result_valid&&sample_count==0,"active reset cancels window");
 $display("PASS range statistics oracle late flags full capacity overflow ownership reset");$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
