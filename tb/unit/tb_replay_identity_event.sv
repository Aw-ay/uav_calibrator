`timescale 1ns/1ps
module tb_replay_identity_event;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,capture_valid=0,event_ready=0;reg [1535:0] task_context=0;reg [63:0] lifecycle_token=0;
 wire capture_ready,capture_rejected,event_valid;wire [511:0] event_data;
 replay_identity_event dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 integer fd;string path;reg [511:0] saved;
 initial begin
  if(!$value$plusargs("OUT=%s",path))path="replay_identity_records.txt";
  fd=$fopen(path,"w");if(!fd)$fatal(1,"fixture output");
  repeat(3)tick;rst=0;tick;
  lifecycle_token=64'h1234567887654321;
  task_context[768+:64]=64'hfedcba9876543210;task_context[128+:64]=64'h1122334455667788;
  task_context[0+:64]=64'habcdef0102030405;task_context[64+:64]=64'h8877665544332211;
  task_context[448+:32]=7;task_context[480+:32]=9;task_context[512+:32]=11;
  task_context[320+:32]=3;task_context[352+:32]=2;
  capture_valid=1;tick;capture_valid=0;
  if(!event_valid||event_data[31:0]!=32'h60001||event_data[63:32]!=0)$fatal(1,"identity tag/reserved");
  if(event_data[64+:64]!=lifecycle_token||event_data[128+:64]!=64'hfedcba9876543210||event_data[192+:64]!=64'h1122334455667788)$fatal(1,"full task identity");
  if(event_data[256+:64]!=64'habcdef0102030405||event_data[320+:64]!=64'h8877665544332211||event_data[384+:32]!=7||event_data[416+:32]!=9||event_data[448+:32]!=11||event_data[480+:16]!=3||event_data[496+:16]!=2)$fatal(1,"owner/config/bank identity");
  saved=event_data;task_context=0;lifecycle_token=0;
  repeat(8)begin tick;if(event_data!==saved||!event_valid||capture_ready)$fatal(1,"stalled identity mutated");end
  capture_valid=1;tick;if(!capture_rejected||event_data!==saved)$fatal(1,"busy overwrite");capture_valid=0;
  for(integer w=0;w<16;w=w+1)$fwrite(fd,"%08x ",event_data[w*32+:32]);$fwrite(fd,"\n");
  event_ready=1;tick;event_ready=0;
  capture_valid=1;tick;if(!capture_rejected||event_valid)$fatal(1,"invalid token/group accepted");capture_valid=0;
  task_context[320+:32]=32'h10003;task_context[352+:32]=2;lifecycle_token=1;
  capture_valid=1;tick;if(!capture_rejected||event_valid)$fatal(1,"group truncated before validation");capture_valid=0;
  task_context[320+:32]=1;task_context[352+:32]=4;capture_valid=1;tick;if(!capture_rejected||event_valid)$fatal(1,"bank bounds");capture_valid=0;
  task_context[352+:32]=0;lifecycle_token=64'hffffffffffffffff;capture_valid=1;tick;capture_valid=0;
  if(!event_valid)$fatal(1,"second identity");
  for(integer w=0;w<16;w=w+1)$fwrite(fd,"%08x ",event_data[w*32+:32]);$fwrite(fd,"\n");
  rst=1;tick;rst=0;tick;if(event_valid||!capture_ready)$fatal(1,"reset");
  $fclose(fd);$display("PASS replay identity event full64 context stable stall invalid token group bank reset");$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
