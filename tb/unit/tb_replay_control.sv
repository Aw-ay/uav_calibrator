`timescale 1ns/1ps
module tb_replay_control;
import replay_control_layout_pkg::*;
reg clk=0;always #5 clk=~clk;
reg rst=1,push=0,reader_ready=0,evaluation_valid=1,retire=0,reject_ready=0;
reg [TASK_BITS-1:0] input_task=0,retire_task=0;
wire [TASK_BITS-1:0] head_task,dispatch_task,rejected_task;
wire head_valid,dispatch_valid,rejected_valid,accepted,push_rejected,busy,legal;
wire [7:0] reason,push_reason,reject_reason;wire [31:0] queued;
reg [63:0] gsc=100,epoch=5,generation=7;
reg [31:0] config_id=11,fir_id=12,source_epoch=13;
reg data_ready=1,qualified=1,lease=1,source_stable=1,profiles=1,guard=1,slot=1,rf=1,binding=1,resources=1,latency_valid=1,time_valid=1;
wire [63:0] first_gsc;
replay_legality_checker check_dut(.task_data(head_task),.gsc(gsc),.current_owner_epoch(epoch),.current_generation(generation),.current_config_id(config_id),.current_fir_id(fir_id),.current_source_epoch(source_epoch),.data_ready(data_ready),.qualified(qualified),.lease_pinned(lease),.source_stable(source_stable),.allow_aux_replay(1'b0),.task_profiles_valid(profiles),.guard_clear(guard),.planned_slot_clear(slot),.rf_safe(rf),.binding_valid(binding),.resources_ready(resources),.time_valid(time_valid),.latency_validated(latency_valid),.fractional_supported(1'b0),.downstream_latency_ticks(64'd8),.legal(legal),.reason(reason),.first_output_gsc(first_gsc));
replay_descriptor_queue #(.DEPTH(2)) queue_dut(.clk(clk),.rst(rst),.push_valid(push),.push_task(input_task),.push_accepted(accepted),.push_rejected(push_rejected),.push_reason(push_reason),.head_valid(head_valid),.head_task(head_task),.evaluation_valid(evaluation_valid),.head_legal(legal),.head_reason(reason),.reader_ready(reader_ready),.dispatch_valid(dispatch_valid),.dispatch_task(dispatch_task),.rejected_valid(rejected_valid),.rejected_task(rejected_task),.reject_reason(reject_reason),.reject_ready(reject_ready),.retire_valid(retire),.retire_task(retire_task),.retire_rejected(),.inflight(busy),.queued_count(queued));
task tick;begin @(posedge clk);#1;end endtask
task ck(input bit v,input string msg);if(!v)$fatal(1,"%s",msg);endtask
function automatic [TASK_BITS-1:0] make_task(input integer bank,input integer id);
 reg [TASK_BITS-1:0] t;
 begin t=0;t[OWNER_EPOCH_BIT+:64]=5;t[GENERATION_BIT+:64]=7;t[STREAM_GROUP_ID_BIT+:32]=1;t[BANK_ID_BIT+:32]=bank;t[SAMPLE_COUNT_BIT+:32]=16;t[CONFIG_ID_BIT+:32]=11;t[FIR_ID_BIT+:32]=12;t[SOURCE_EPOCH_BIT+:32]=13;t[SOURCE_ROLE_BIT+:32]=1;t[TARGET_GSC_BIT+:64]=200;t[TASK_ID_BIT+:64]=id;t[OUTPUT_DAC_MASK_BIT+:32]=1;make_task=t;end
endfunction
task load_isolated(input [TASK_BITS-1:0] t);
 begin
  rst=1;tick();rst=0;reader_ready=0;evaluation_valid=0;
  @(negedge clk);input_task=t;push=1;tick();push=0;#1;
 end
endtask
reg [TASK_BITS-1:0] vector_task;
task enqueue(input integer bank,input integer id);begin @(negedge clk);input_task=make_task(bank,id);push=1;tick();@(negedge clk);push=0;end endtask
initial begin
 tick();rst=0;enqueue(0,1);ck(accepted&&queued==1,"enqueue task");ck(legal&&first_gsc==192,"reference latency calculation");
 enqueue(0,2);ck(push_rejected&&queued==1,"one replay reference per bank");enqueue(1,2);ck(accepted&&queued==2,"queue reaches capacity");enqueue(2,3);ck(push_rejected&&queued==2,"queue full explicit rejection");
 reader_ready=1;#1;ck(dispatch_valid&&dispatch_task[TASK_ID_BIT+:64]==1,"first task dispatch");tick();ck(busy&&queued==1&&!dispatch_valid,"single engine blocked until actual retire");
 enqueue(0,3);ck(push_rejected,"dispatched bank remains reserved");retire_task=make_task(0,99);retire=1;tick();ck(busy,"stale retire rejected");retire_task=make_task(0,1);tick();retire=0;ck(!busy,"matching actual-reader completion retires");
 generation=8;tick();ck(rejected_valid&&reject_reason==4&&queued==0,"generation rechecked at dequeue");repeat(3)tick();ck(rejected_valid&&rejected_task[TASK_ID_BIT+:64]==2,"rejection held for owner disposition");reject_ready=1;tick();reject_ready=0;generation=7;reader_ready=0;
 enqueue(0,4);gsc=196;#1;ck(!legal&&reason==9,"queued task deadline expires");gsc=100;
 source_stable=0;#1;ck(!legal,"settling rejected");source_stable=1;source_epoch=14;#1;ck(!legal,"source epoch changed");source_epoch=13;
 config_id=10;#1;ck(!legal,"config mismatch");config_id=11;epoch=6;#1;ck(!legal,"owner epoch mismatch");epoch=5;
 guard=0;#1;ck(!legal,"guard conflict");guard=1;slot=0;#1;ck(!legal,"planned RX/TX slot conflict");slot=1;
 binding=0;#1;ck(!legal,"RF unbound");binding=1;rf=0;#1;ck(!legal,"RF unsafe");rf=1;resources=0;#1;ck(!legal,"port unavailable");resources=1;
 // Drop current head via actual dequeue recheck, then test forbidden source roles.
 profiles=0;reader_ready=1;tick();ck(rejected_valid&&!dispatch_valid,"unpinned profile rejection");reject_ready=1;tick();reject_ready=0;profiles=1;reader_ready=0;
 @(negedge clk);input_task=make_task(2,8);input_task[SOURCE_ROLE_BIT+:32]=3;push=1;tick();push=0;#1;ck(!legal,"RF loopback forbidden");reader_ready=1;tick();reject_ready=1;tick();reject_ready=0;reader_ready=0;
 @(negedge clk);input_task=make_task(3,9);input_task[SOURCE_ROLE_BIT+:32]=0;push=1;tick();push=0;#1;ck(!legal,"unknown source forbidden");
 // Independent boundary vectors: never accept wraparound as a future deadline.
 vector_task=make_task(0,20);vector_task[TARGET_GSC_BIT+:64]=104;load_isolated(vector_task);ck(!legal&&reason==9,"earliest start deadline");
 vector_task[TARGET_GSC_BIT+:64]=116;load_isolated(vector_task);ck(legal&&first_gsc==108,"exact earliest start accepted");
 vector_task[TARGET_GSC_BIT+:64]=117;load_isolated(vector_task);ck(!legal&&reason==8,"phase misalignment rejected");
 vector_task[TARGET_GSC_BIT+:64]=4;load_isolated(vector_task);ck(!legal&&reason==7,"latency subtraction underflow");
 vector_task[TARGET_GSC_BIT+:64]=64'hfffffffffffffff0;load_isolated(vector_task);ck(!legal&&reason==7,"last sample time overflow");
 vector_task=make_task(0,21);vector_task[TARGET_GSC_BIT+:64]=100000;load_isolated(vector_task);ck(legal,"long delay allowed when slot is clear");
 vector_task[SAMPLE_COUNT_BIT+:32]=0;load_isolated(vector_task);ck(!legal&&reason==5,"zero length rejected");
 vector_task=make_task(0,22);vector_task[REFERENCE_SAMPLE_INDEX_BIT+:32]=16;load_isolated(vector_task);ck(!legal&&reason==5,"reference outside capture");
 vector_task=make_task(0,23);vector_task[FRACTION_Q32_BIT+:32]=1;load_isolated(vector_task);ck(!legal&&reason==6,"unimplemented fractional timing rejected");
 vector_task=make_task(0,24);vector_task[OUTPUT_DAC_MASK_BIT+:32]=256;load_isolated(vector_task);ck(!legal&&reason==5,"DAC mask outside eight lanes");
 vector_task=make_task(0,25);load_isolated(vector_task);data_ready=0;#1;ck(!legal,"capture completion required");data_ready=1;
 qualified=0;#1;ck(!legal,"statistics qualification required");qualified=1;lease=0;#1;ck(!legal,"bank lease pin required");lease=1;
 fir_id=99;#1;ck(!legal&&reason==4,"FIR version mismatch");fir_id=12;latency_valid=0;#1;ck(!legal&&reason==6,"unvalidated latency");latency_valid=1;
 gsc=64'hfffffffffffffffc;#1;ck(!legal&&reason==7,"current time horizon overflow");gsc=100;
 $display("PASS replay control: queue capacity, ownership, retirement, deadline and dequeue safety rechecks");$finish;
end
initial begin #20000;$fatal(1,"timeout");end
endmodule
