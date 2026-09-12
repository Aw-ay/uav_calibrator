`timescale 1ns/1ps
// Independent burst oracle: payload ends at start+width, event arrives
// hold-1 edges later. Full signed four-component energy uses 64-bit math.
module tb_detector_scoreboard;
 reg clk=0; always #4 clk=~clk;
 reg rst=1,sample_valid=1,time_valid=1,source_valid=1;
 reg [63:0] sample_seq=0,iq=0;
 reg cfg_enable=1,cfg_validated=1;
 reg [32:0] cfg_on_power=100,cfg_off_power=25;
 reg [13:0] cfg_eop_hold=3,cfg_max_body=15000;
 reg noise_qualified=0; reg [4:0] cfg_noise_shift=1;
 wire active,onset_valid,event_valid,event_precise,event_truncated;
 wire [63:0] onset_seq,event_onset_seq,event_end_seq;
 wire [3:0] event_reason;
 wire [32:0] sample_power,noise_power;
 wire noise_valid; wire [31:0] onset_count,pulse_count,abort_count;
 pulse_detector dut(.*);
 reg [31:0] rng=32'hc0512025;
 integer cases=0,energies=0,normal_cases=0,fault_cases=0,reset_cases=0;
 integer width,hold_cycles,kind;
 reg [63:0] first;
 function automatic [31:0] next_random(input [31:0] x);
  reg [31:0] y;
  begin y=x^(x<<13);y=y^(y>>17);next_random=y^(y<<5);end
 endfunction
 task check(input bit ok,input string msg);
  if(!ok) $fatal(1,"case=%0d seq=%0d: %s",cases,sample_seq,msg);
 endtask
 task step(input [63:0] word);
  longint signed a,b,c,d;
  longint unsigned expected_power;
  begin
   @(negedge clk);iq=word;sample_seq=sample_seq+1;
   a=$signed(word[15:0]);b=$signed(word[31:16]);
   c=$signed(word[47:32]);d=$signed(word[63:48]);
   expected_power=a*a+b*b+c*c+d*d;
   @(posedge clk);#1;
   check(sample_power===expected_power[32:0],"four-component signed energy");
   energies=energies+1;
  end
 endtask
 initial begin
  if($test$plusargs("waves")) begin
   $dumpfile("detector_scoreboard.vcd");$dumpvars(0,tb_detector_scoreboard);
  end
  repeat(2) @(posedge clk);@(negedge clk);rst=0;
  for(cases=0;cases<256;cases=cases+1) begin
   rng=next_random(rng);width=1+(rng%40);
   rng=next_random(rng);hold_cycles=1+(rng%12);
   kind=cases%4;cfg_eop_hold=hold_cycles;source_valid=1;
   step(0);check(!active&&!event_valid,"idle/rearm");
   first=sample_seq+1;
   // Exactly on threshold; a strict > comparison must fail this check.
   step(64'd10);check(onset_valid&&active&&onset_seq==first,"on threshold onset");
   for(integer j=1;j<width;j=j+1) begin
    rng=next_random(rng);iq={rng,~rng};
    step(iq);check(active&&!event_valid&&!onset_valid,"random signed body");
   end
   if(kind==1) begin
    source_valid=0;step(0);
    check(event_valid&&!event_precise&&event_truncated&&event_reason==4,
          "invalid source abort");
    check(event_onset_seq==first&&event_end_seq==first+width,"abort metadata");
    source_valid=1;step(64'd100);check(!active&&!onset_valid,"abort lockout");
    fault_cases=fault_cases+1;
   end else if(kind==2) begin
    @(negedge clk);rst=1;@(posedge clk);#1;
    check(!active&&!event_valid&&!onset_valid&&onset_count==0,"mid-pulse reset");
    @(negedge clk);iq=0;rst=0;reset_cases=reset_cases+1;
   end else begin
    for(integer j=1;j<=hold_cycles;j=j+1) begin
     step(0);
     if(j<hold_cycles) check(active&&!event_valid,"hold must not end early");
    end
    check(event_valid&&event_precise&&!event_truncated&&event_reason==0,"precise event");
    check(event_onset_seq==first&&event_end_seq==first+width,"exclusive end excludes hold");
    check(sample_seq==first+width+hold_cycles-1,"event arrival edge");
    normal_cases=normal_cases+1;
   end
  end
  check(normal_cases==128&&fault_cases==64&&reset_cases==64,"coverage counters");
  $display("PASS detector scoreboard cases=256 normal=%0d fault=%0d reset=%0d energies=%0d",
           normal_cases,fault_cases,reset_cases,energies);
  $finish;
 end
 initial begin #1000000;$fatal(1,"watchdog timeout");end
endmodule
