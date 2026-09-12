`timescale 1ns/1ps
module tb_noise_snapshot;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,clear_estimate=0,offpulse_enable=0,snapshot_request=0,result_ready=0;
 reg [95:0] iq_i=0,iq_q=0;reg [5:0] sample_good=63;
 reg [4:0] ewma_shift=1;reg [31:0] max_age_cycles=1000;
 reg [14:0] window_count=4;
 reg [63:0] pulse_id=7,context_version=3;
 wire snapshot_ready,result_valid,rejected;
 wire [63:0] result_id,result_context;
 wire [191:0] noise_power;wire [5:0] noise_known;
 noise_snapshot dut(.*);
 wire [275:0] converted_energy;wire [5:0] converted_known;
 noise_window_energy convert(.noise_power(noise_power),.noise_known(noise_known),
  .sample_count(window_count),.noise_energy(converted_energy),.energy_known(converted_known));
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 task consume;begin result_ready=1;tick();result_ready=0;end endtask
 initial begin
 tick();rst=0;snapshot_request=1;tick();snapshot_request=0;
 check(result_valid&&noise_known==0,"unseeded unknown");consume();
 offpulse_enable=1;
 for(integer c=0;c<6;c=c+1)begin iq_i[c*16+:16]=3*(c+1);iq_q[c*16+:16]=4*(c+1);end
 tick();offpulse_enable=0;snapshot_request=1;tick();snapshot_request=0;
 check(noise_known==63&&result_id==7&&result_context==3,"seed identity");
 for(integer c=0;c<6;c=c+1)check(noise_power[c*32+:32]==25*(c+1)*(c+1),"independent square sum");
 for(integer c=0;c<6;c=c+1)check(converted_energy[c*46+:46]==100*(c+1)*(c+1),"matched window noise energy");
 offpulse_enable=1;iq_i=0;iq_q=0;repeat(5)tick();offpulse_enable=0;
 check(noise_power[31:0]==25,"queued snapshot immutable");snapshot_request=1;tick();snapshot_request=0;
 check(rejected&&noise_power[31:0]==25,"busy snapshot reject");consume();
 snapshot_request=1;tick();snapshot_request=0;check(noise_power[31:0]==1,"falling EWMA integer rounding");consume();
 clear_estimate=1;tick();clear_estimate=0;sample_good=6'b000001;
 iq_i={6{16'h8000}};iq_q={6{16'h8000}};offpulse_enable=1;tick();offpulse_enable=0;
 snapshot_request=1;tick();snapshot_request=0;
 check(noise_known==1&&noise_power[31:0]==32'h80000000,"signed extreme and independent validity");
 window_count=16384;#1;check(converted_energy[45:0]==46'd35184372088832,"full-scale window exact energy");
 window_count=16385;#1;check(converted_known==0,"invalid window no noise qualification");window_count=4;consume();
 max_age_cycles=2;repeat(4)tick();snapshot_request=1;tick();snapshot_request=0;
 check(noise_known==0,"stale estimate unknown");consume();
 max_age_cycles=1000;context_version=4;snapshot_request=1;tick();snapshot_request=0;
 check(noise_known==0,"context changed invalidates seed");consume();
 sample_good=63;offpulse_enable=1;iq_i={6{16'd3}};iq_q={6{16'd4}};tick();
 // Snapshot must use preceding estimator state, not same-edge new power.
 iq_i={6{16'd30}};iq_q={6{16'd40}};snapshot_request=1;tick();snapshot_request=0;offpulse_enable=0;
 check(noise_known==63&&noise_power[31:0]==25,"causal snapshot before same-edge update");consume();
 max_age_cycles=0;snapshot_request=1;tick();snapshot_request=0;check(noise_known==0,"unset freshness budget");consume();
 clear_estimate=1;snapshot_request=1;tick();clear_estimate=0;snapshot_request=0;
 check(rejected&&!result_valid,"clear rejects snapshot");
 rst=1;tick();rst=0;check(snapshot_ready&&!result_valid,"reset ownership");
 $display("PASS noise snapshot six lanes seed EWMA signed extrema freshness context causality ownership");$finish;
 end
 initial begin #10000;$fatal(1,"watchdog");end
endmodule
