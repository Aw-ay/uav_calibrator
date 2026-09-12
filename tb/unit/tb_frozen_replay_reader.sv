module tb_frozen_replay_reader;
 reg clk=0; always #4 clk=~clk;
 reg rst=1;
 reg [63:0] gsc=0,current_owner_epoch=5,current_generation=7;
 reg [31:0] current_config_id=11,current_fir_id=12,current_source_epoch=13;
 reg time_valid=1,clock_ok=1,hard_fault=0,abort_request=0;
 reg task_valid=0,task_frozen=1,task_qualified=1,task_external_source=1,task_lease_pinned=1,latency_validated=1;
 reg [63:0] task_owner_epoch=5,task_generation=7,task_id=42;
 reg [31:0] task_group=2,task_bank=3,task_start_ptr=0,task_count=1,task_reference_index=0;
 reg [31:0] task_config_id=11,task_fir_id=12,task_source_epoch=13;
 reg [63:0] task_target_gsc=0,downstream_latency_ticks=20;
 wire task_ready,accepted,rejected,busy,ram_en,source_valid,actual_start,actual_finish,token_valid;
 wire [7:0] reason,token_status;
 wire [31:0] accepted_count,rejected_count,aborted_count,completed_count,ram_group,ram_bank,token_group,token_bank,token_consumer;
 wire [13:0] ram_addr;
 reg ram_response_valid=0;
 reg [63:0] ram_data=0;
 wire [63:0] source_data,actual_start_gsc,actual_finish_gsc,active_task_id,token_owner_epoch,token_generation;
 reg token_ready=0;
 frozen_replay_reader dut(.*);
 reg drop_response=0,dma_ready=0;
 function [63:0] sample(input integer a);
  sample={16'hA123,a[15:0],16'hB456,(a[15:0]^16'h789A)};
 endfunction
 integer reads=0;
 always @(posedge clk) begin
  ram_response_valid<=ram_en && !drop_response;
  if(ram_en) begin ram_data<=sample(ram_addr); reads=reads+1; end
  dma_ready<=!dma_ready;
 end
 task tick;
  begin @(negedge clk); gsc=gsc+4; @(posedge clk); #1; end
 endtask
 task release_token;
  begin
   if(!token_valid || token_owner_epoch!=5 || token_generation!=7 || token_group!=2 || token_bank!=3 || token_consumer!=2) $fatal(1,"bad token");
   tick; if(!token_valid) $fatal(1,"token not retained");
   token_ready=1; tick; token_ready=0;
  end
 endtask
 task reject_case(input [7:0] why);
  begin task_valid=1; tick; task_valid=0;
   if(!rejected || accepted || reason!=why || ram_en || token_valid) $fatal(1,"reject expected %0d got %0d",why,reason);
  end
 endtask
 integer n,i,seen,base_reads;
 reg [63:0] expected_first;
 task golden(input integer start,input integer count,input integer refidx);
  begin
   task_start_ptr=start; task_count=count; task_reference_index=refidx;
   expected_first=gsc+48;
   task_target_gsc=expected_first+20+4*refidx;
   task_valid=1; tick; task_valid=0;
   if(!accepted) $fatal(1,"not accepted %0d",reason);
   // Mutating descriptor/version inputs after acceptance must not change task.
   task_start_ptr=999; task_count=3; task_target_gsc=0; current_config_id=99;
   seen=0; base_reads=reads;
   while(!token_valid) begin
    tick;
    if(source_valid) begin
     if(gsc!=expected_first+4*seen || source_data!==sample((start+seen)%16384)) $fatal(1,"sample/time mismatch idx%0d time%0d",seen,gsc);
     if(actual_start!=(seen==0)) $fatal(1,"start event");
     seen=seen+1;
    end else if(source_data!==0) $fatal(1,"idle nonzero");
   end
   if(seen!=count || reads-base_reads!=count || !actual_finish || actual_start_gsc!=expected_first || actual_finish_gsc!=expected_first+4*(count-1) || token_status!=0) $fatal(1,"completion mismatch");
   current_config_id=11; release_token; tick;
   if(source_valid || source_data!=0) $fatal(1,"stale output");
  end
 endtask
 initial begin
  tick; rst=0; tick;
  golden(17,1,0); golden(16382,5,2); golden(16383,16384,250);
  task_count=4; task_reference_index=1; task_start_ptr=4;
  task_target_gsc=gsc+100;
  task_frozen=0; reject_case(3); task_frozen=1;
  task_qualified=0; reject_case(3); task_qualified=1;
  task_external_source=0; reject_case(3); task_external_source=1;
  task_lease_pinned=0; reject_case(3); task_lease_pinned=1;
  task_generation=8; reject_case(4); task_generation=7;
  task_config_id=99; reject_case(4); task_config_id=11;
  task_fir_id=99; reject_case(4); task_fir_id=12;
  task_source_epoch=99; reject_case(4); task_source_epoch=13;
  latency_validated=0; reject_case(6); latency_validated=1;
  task_target_gsc=1; reject_case(7);
  task_target_gsc=gsc+101; reject_case(8);
  task_target_gsc=gsc+24; reject_case(9);
  task_target_gsc=64'hfffffffffffffffc; task_reference_index=0; downstream_latency_ticks=0; reject_case(7);
  downstream_latency_ticks=20;
  task_target_gsc=gsc+100; task_valid=1; tick; task_valid=0;
  if(!accepted) $fatal(1,"fault setup");
  task_valid=1; tick; task_valid=0; if(!rejected || reason!=1) $fatal(1,"busy rejection");
  base_reads=reads; while(reads==base_reads) tick;
  tick; hard_fault=1; #1; if(source_data!=0 || source_valid) $fatal(1,"hard gate");
  tick; if(!token_valid || token_status!=10) $fatal(1,"fault drain");
  hard_fault=0; release_token;
  // Missing response after accepted read must abort and drain an overlapping read.
  task_target_gsc=gsc+80; task_valid=1; tick; task_valid=0; drop_response=1;
  while(!token_valid) tick;
  if(token_status!=11 || source_valid) $fatal(1,"underflow");
  drop_response=0; release_token;
  task_target_gsc=gsc+80; task_valid=1; tick; task_valid=0;
  base_reads=reads; while(reads==base_reads) tick;
  tick; current_owner_epoch=6; tick;
  if(!token_valid || token_status!=10) $fatal(1,"epoch abort");
  current_owner_epoch=5; release_token;
  task_target_gsc=gsc+80; task_valid=1; tick; task_valid=0;
  base_reads=reads; while(reads==base_reads) tick;
  clock_ok=0; #1; if(source_valid || source_data!=0 || ram_en) $fatal(1,"clock gate");
  tick; if(!token_valid || token_status!=10) $fatal(1,"clock cancel");
  clock_ok=1; release_token;
  task_target_gsc=gsc+80; task_valid=1; tick; task_valid=0;
  time_valid=0; tick; if(!token_valid || token_status!=10) $fatal(1,"time invalid cancel");
  time_valid=1; release_token;
  task_target_gsc=gsc+80; task_valid=1; tick; task_valid=0;
  abort_request=1; tick; if(!token_valid || token_status!=10) $fatal(1,"explicit cancel");
  abort_request=0; release_token;
  task_target_gsc=gsc+80; task_valid=1; tick; task_valid=0;
  @(negedge clk); gsc=gsc+8; @(posedge clk); #1;
  if(!token_valid || token_status!=12) $fatal(1,"time jump cancel");
  release_token;
  task_count=0; task_target_gsc=gsc+100; reject_case(5); task_count=4;
  task_reference_index=4; reject_case(5); task_reference_index=0;
  task_owner_epoch=6; reject_case(4); task_owner_epoch=5;
  downstream_latency_ticks=64'hffffffffffffffff; task_target_gsc=16; reject_case(7); downstream_latency_ticks=20;
  // Test unsigned high-half valid schedule (no signed subtraction shortcut).
  @(negedge clk); gsc=64'h8000000000000000; @(posedge clk); #1;
  golden(3,3,1);
  $display("PASS frozen replay reader: golden singleton odd wrap full bank pretrigger high64, rejects busy/context/time/quality, fault/underflow/epoch drain, zero gating; completed=%0d rejected=%0d aborted=%0d",completed_count,rejected_count,aborted_count);
  $finish;
 end
 initial begin #2000000; $fatal(1,"timeout"); end
endmodule

