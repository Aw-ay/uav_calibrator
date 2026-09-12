`timescale 1ns/1ps
module tb_pulse_detector;
 reg clk=0; always #4 clk=~clk;
 reg rst=1, sample_valid=1,time_valid=1,source_valid=1;
 reg [63:0] sample_seq=0,iq=0;
 reg cfg_enable=0,cfg_validated=0;
 reg [32:0] cfg_on_power=100,cfg_off_power=25;
 reg [13:0] cfg_eop_hold=3,cfg_max_body=20;
 reg noise_qualified=0; reg [4:0] cfg_noise_shift=1;
 wire active,onset_valid,event_valid,event_precise,event_truncated;
 wire [63:0] onset_seq,event_onset_seq,event_end_seq;
 wire [3:0] event_reason;
 wire [32:0] sample_power,noise_power;
 wire noise_valid; wire [31:0] onset_count,pulse_count,abort_count;
 pulse_detector dut(.*);
 task tick(input [63:0] seq,input integer amp);
 begin @(negedge clk);sample_seq=seq;iq={48'd0,amp[15:0]}; @(posedge clk); #1; end endtask
 task check(input bit ok,input string msg); if(!ok) $fatal(1,"%s",msg); endtask
 task reset_dut; begin @(negedge clk);rst=1;@(posedge clk);#1;rst=0;end endtask
 initial begin
 reset_dut(); tick(0,20);check(!onset_valid&&!active,"disabled");
 cfg_enable=1;tick(1,20);check(!active,"unvalidated");cfg_validated=1;
 tick(2,10);check(onset_valid&&onset_seq==2&&active,"onset same accepted edge");
 tick(3,6);tick(4,0);tick(5,0);check(!event_valid,"hold pending");
 tick(6,0);check(event_valid&&event_precise&&!event_truncated&&event_end_seq==4&&event_onset_seq==2,"true exclusive tail");
 tick(7,10);tick(8,0);tick(9,0);tick(10,5);tick(11,0);tick(12,0);tick(13,0);
 check(event_valid&&event_end_seq==11&&event_onset_seq==7,"retrigger within hold incl off equality");
 tick(14,10); cfg_off_power=1000;cfg_eop_hold=1;cfg_max_body=1;cfg_enable=0;cfg_validated=0;
 tick(15,6);tick(16,0);check(!event_valid,"latched hold");tick(17,0);tick(18,0);
 check(event_valid&&event_precise&&event_end_seq==16,"latched config");
 cfg_enable=1;cfg_validated=1;cfg_off_power=25;cfg_max_body=3;cfg_eop_hold=3;
 tick(19,10);tick(20,10);tick(21,10);check(!event_valid,"maximum inclusive width");tick(22,10);
 check(event_valid&&!event_precise&&event_truncated&&event_reason==8,"max abort");
 tick(23,10);check(!onset_valid,"max lockout");tick(24,0);cfg_max_body=20;
 tick(25,10);tick(27,10);check(event_valid&&event_reason==1&&!event_precise,"sequence gap abort");
 tick(28,0);tick(29,10);time_valid=0;tick(30,10);check(event_valid&&event_reason==2,"time invalid");time_valid=1;
 tick(31,0);tick(32,10);source_valid=0;tick(33,10);check(event_valid&&event_reason==4,"source invalid");source_valid=1;
 tick(34,0);tick(35,10);sample_valid=0;tick(36,10);check(event_valid&&event_reason==1,"missing beat abort");sample_valid=1;
 tick(37,0);check(onset_count==8&&pulse_count==3&&abort_count==5,"counters");
 tick(38,10);reset_dut();check(!active&&!event_valid&&onset_count==0,"reset cancels");
 cfg_on_power=33'd4294967296;cfg_off_power=25;
 @(negedge clk);sample_seq=100;iq=64'h8000800080008000;@(posedge clk);#1;
 check(sample_power==33'd4294967296&&onset_valid,"unsigned square maximum");
 reset_dut();cfg_on_power=100;cfg_eop_hold=0;cfg_max_body=0;
 tick(200,10);for(integer n=201;n<325;n=n+1)begin tick(n,0);check(!event_valid,"default125 early");end
 tick(325,0);check(event_valid&&event_end_seq==201,"default125 end");
 noise_qualified=0;tick(326,4);check(!noise_valid,"noise requires explicit qualification");
 noise_qualified=1;tick(327,4);check(noise_valid&&noise_power==16,"noise seed");
 tick(328,2);check(noise_power==10,"noise explicit EWMA shift");noise_qualified=0;tick(329,8);check(noise_power==10,"unqualified noise frozen");
 cfg_on_power=1;cfg_off_power=2;tick(330,10);check(!active,"invalid hysteresis config");

 // A missing epoch before onset cannot qualify a high sample as true onset.
 reset_dut();cfg_on_power=100;cfg_off_power=25;cfg_eop_hold=1;
 tick(500,0);tick(502,10);tick(503,10);check(!onset_valid&&!active,"gap idle lockout");
 tick(504,0);tick(505,10);check(onset_valid,"idle gap rearm after known low");
 tick(506,0);check(event_valid&&event_end_seq==506,"hold one");
 reset_dut();cfg_max_body=0;cfg_eop_hold=3;
 tick(1000,10);
 for(integer n=1001;n<16000;n=n+1) tick(n,10);
 check(active&&!event_valid,"default max15000 permits body");
 tick(16000,0);tick(16001,0);tick(16002,0);
 check(event_valid&&event_precise&&event_end_seq==16000,"15000 body tail hold allowed");
 tick(16003,10);
 for(integer n=16004;n<31003;n=n+1) tick(n,10);
 tick(31003,10);check(event_valid&&event_reason==8,"default max15000 overflow");
 reset_dut();cfg_max_body=15001;tick(40000,10);check(!active,"reject oversized max");
 cfg_max_body=20;tick(40001,10);sample_valid=0;time_valid=0;source_valid=0;
 tick(40002,10);check(event_valid&&event_reason==7&&!event_precise,"combined invalid flags");
 $display("PASS pulse_detector");$finish;
 end
endmodule

