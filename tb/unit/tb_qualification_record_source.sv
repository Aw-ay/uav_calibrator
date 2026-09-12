`timescale 1ns/1ps
module tb_qualification_record_source;
 reg rst=0,event_valid=0,event_published=1,event_rejected=0;
 reg [3:0] event_bank=0,desc_ready=0,stale_descriptor=0;
 reg [1023:0] event_header=1024'h1234;
 reg [63:0] event_generation=77,event_epoch=88;
 wire event_ready,disposition_valid,descriptor_accepted,disposition_rejected;
 wire [3:0] desc_valid;wire [4095:0] desc_headers;wire [7:0] desc_banks;
 wire [255:0] source_expected_epoch,source_expected_generation;
 qualification_record_source dut(.*);
 initial begin
  #1;if(desc_valid||event_ready||disposition_valid)$fatal(1,"idle");
  event_valid=1;
  for(integer b=0;b<12;b=b+1)begin
   event_bank=b;desc_ready=0;#1;
   if(desc_valid!=(1<<(b/4))||event_ready||disposition_valid)$fatal(1,"routing/backpressure");
   if(desc_banks[(b/4)*2+:2]!=(b%4)||desc_headers[(b/4)*1024+:1024]!=event_header||
      source_expected_epoch[(b/4)*64+:64]!=88||source_expected_generation[(b/4)*64+:64]!=77)$fatal(1,"identity");
   desc_ready=1<<((b/4+1)%4);#1;if(event_ready)$fatal(1,"unrelated ready");
   desc_ready=1<<(b/4);#1;if(!descriptor_accepted||disposition_rejected)$fatal(1,"accept");
   desc_ready=0;stale_descriptor=1<<(b/4);#1;
   if(!event_ready||!disposition_rejected||descriptor_accepted||desc_valid!=(1<<(b/4)))$fatal(1,"explicit stale disposition");
   stale_descriptor=0;
  end
  event_bank=12;#1;if(desc_valid||!disposition_rejected||descriptor_accepted)$fatal(1,"AUX not normal range");
  event_bank=0;event_published=0;#1;
  if(desc_valid||!disposition_valid||disposition_rejected||descriptor_accepted)$fatal(1,"no-range disposition");
  event_rejected=1;#1;if(!disposition_rejected||desc_valid)$fatal(1,"rejected input");
  rst=1;#1;if(event_ready||disposition_valid||desc_valid)$fatal(1,"reset");
  $display("PASS qualification record source all primary banks stall stale discard reset");$finish;
 end
endmodule
