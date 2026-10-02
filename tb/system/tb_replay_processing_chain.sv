`timescale 1ns/1ps
module tb_replay_processing_chain;
reg clk=0;always #4 clk=~clk;reg rst=1,profile_commit=0,hard_fault=0;
reg [1:0] shadow_cal_valid=3;reg [63:0] shadow_dc={16'd40,16'd30,16'd20,16'd10};
reg [71:0] shadow_gain={18'd0,18'd32768,18'd0,18'd65536};
reg [143:0] shadow_matrix={18'd0,18'd0,18'd0,18'd65536,18'd0,18'd65536,18'd0,18'd0};
reg [7:0] shadow_fd_phase=0;reg [31:0] shadow_fd_version=32'h9d1dc12a;
reg phase_valid=1;reg signed [17:0] phase_i=0,phase_q=65536;
reg in_valid=0,in_last=0;reg [63:0] in_hv=0;
wire profile_ready,profile_accepted,profile_rejected,source_ready,busy,done,cancelled;
wire [63:0] out_hv;wire out_valid,out_qualified,arithmetic_saturated;wire [31:0] table_version;
replay_processing_chain dut(.*);
integer received=0;reg checking=1;reg [63:0] expected;integer n;
always @(posedge clk)begin #1;
 if(!rst&&out_valid&&checking)begin
  expected=0;
  if(received<8)begin n=received;expected={16'(100+2*n),16'(-200-2*n),16'(150+n),16'(-200-n)};end
  if(out_hv!==expected||!out_qualified)$fatal(1,"full arithmetic sample %0d got %h expected %h",received,out_hv,expected);
  received=received+1;
 end
end
task tick;begin @(posedge clk);#2;@(negedge clk);end endtask
initial begin tick();rst=0;profile_commit=1;tick();profile_commit=0;#1;if(!profile_accepted||!source_ready)$fatal(1,"profile");
 for(integer s=0;s<8;s=s+1)begin in_valid=1;in_last=s==7;in_hv={16'(440+2*s),16'(330+2*s),16'(220+2*s),16'(110+2*s)};tick();end
 in_valid=0;in_last=0;shadow_dc=0;shadow_matrix=0;profile_commit=1;tick();profile_commit=0;
 if(!profile_rejected||source_ready)$fatal(1,"immutable active profile and closed input");
 wait(done);tick();if(received!=8||busy)$fatal(1,"exact RAW count, no FD zeros received %0d",received);
 checking=0;in_valid=1;repeat(5)tick();hard_fault=1;#1;if(out_hv!=0||out_valid)$fatal(1,"fault zero");tick();in_valid=0;hard_fault=0;
 wait(!busy);repeat(3)tick();if(!cancelled||source_ready||out_hv!=0)$fatal(1,"fault requires new profile");
 profile_commit=1;tick();profile_commit=0;#1;if(!source_ready||cancelled)$fatal(1,"new safe profile");
 $display("PASS replay processing chain actual RXCAL Target matrix phase drain fault");$finish;end
initial begin #100000;$fatal(1,"watchdog");end
endmodule
