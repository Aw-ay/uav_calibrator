`timescale 1ns/1ps
module tb_replay_task_dispatcher;
import replay_control_layout_pkg::*;
reg clk=0;always #4 clk=~clk;
reg rst=1;reg[63:0] gsc=0;always @(posedge clk)if(rst)gsc<=0;else gsc<=gsc+4;
reg drop_response=0;
reg submit_valid=0,lookup_ready=1,processing_ready=0,reject_ready=0,token_ready=0,hard_fault=0,abort_request=0,binding_valid=1;
reg[1535:0] submit_task=0;wire[1535:0] lookup_task,active_task,rejected_task;
reg[63:0] current_owner_epoch=5,current_generation=7;
wire submit_accepted,submit_rejected,lookup_valid,rejected_valid,task_started,raw_valid,raw_last,ram_en,token_valid,idle;
wire[7:0] submit_reason,reject_reason,token_status;wire[31:0] queued_count,ram_group,ram_bank,token_group,token_bank,token_consumer;
wire[13:0] ram_addr;wire[63:0] raw_data,token_owner_epoch,token_generation;wire actual_start,actual_finish;wire[63:0] actual_start_gsc,actual_finish_gsc;
wire[1023:0] read_data;wire[15:0] read_valid;reg[15:0] read_en=0;reg[223:0] read_addr=0;reg[15:0] writes=0;reg[13:0] write_addr=0;reg[255:0] group_data=0;
integer read_slot;
always @*begin read_en=0;read_addr=0;read_slot=(ram_group-1)*4+ram_bank;if(ram_en&&ram_group>=1&&ram_group<=4&&ram_bank<4)begin read_en[read_slot]=1;read_addr[read_slot*14+:14]=ram_addr;end end
capture_bank_array mem(.clk_rf(clk),.clk_mem(clk),.quiesce_rf(1'b0),.quiesce_mem(1'b0),.group_data(group_data),.write_enable(writes),.write_address(write_addr),.frozen_rf(writes?16'd0:16'hffff),.frozen_mem(16'd0),.replay_enable(read_en),.replay_address(read_addr),.replay_data(read_data),.replay_valid(read_valid),.record_enable(16'd0),.record_address(208'd0),.record_data(),.record_valid());
wire ram_response_valid=(ram_group>=1&&ram_group<=4&&ram_bank<4)?(read_valid[read_slot]&&!drop_response):1'b0;
wire[63:0] ram_data=(ram_group>=1&&ram_group<=4&&ram_bank<4)?read_data[read_slot*64+:64]:64'd0;
replay_task_dispatcher dut(.clk(clk),.rst(rst),.submit_valid(submit_valid),.submit_task(submit_task),.submit_accepted(submit_accepted),.submit_rejected(submit_rejected),.submit_reason(submit_reason),
.lookup_valid(lookup_valid),.lookup_task(lookup_task),.lookup_ready(lookup_ready),.gsc(gsc),.current_owner_epoch(current_owner_epoch),.current_generation(current_generation),.current_config_id(32'd11),.current_fir_id(32'd12),.current_source_epoch(32'd13),
.bank_frozen(1'b1),.data_ready(1'b1),.qualified(1'b1),.lease_pinned(1'b1),.source_stable(1'b1),.allow_aux_replay(1'b0),.task_profiles_valid(1'b1),.guard_clear(1'b1),.planned_slot_clear(1'b1),.rf_safe(1'b1),.binding_valid(binding_valid),.resources_ready(1'b1),.time_valid(1'b1),.clock_ok(1'b1),.latency_validated(1'b1),.fractional_supported(1'b0),.downstream_latency_ticks(64'd8),.hard_fault(hard_fault),.abort_request(abort_request),.processing_ready(processing_ready),
.rejected_valid(rejected_valid),.rejected_task(rejected_task),.reject_reason(reject_reason),.reject_ready(reject_ready),.task_started(task_started),.active_task(active_task),.raw_valid(raw_valid),.raw_data(raw_data),.raw_last(raw_last),.ram_en(ram_en),.ram_addr(ram_addr),.ram_group(ram_group),.ram_bank(ram_bank),.ram_response_valid(ram_response_valid),.ram_data(ram_data),
.actual_start(actual_start),.actual_finish(actual_finish),.actual_start_gsc(actual_start_gsc),.actual_finish_gsc(actual_finish_gsc),.token_valid(token_valid),.token_ready(token_ready),.token_owner_epoch(token_owner_epoch),.token_generation(token_generation),.token_group(token_group),.token_bank(token_bank),.token_consumer(token_consumer),.token_status(token_status),.queued_count(queued_count),.idle(idle));
function automatic[1535:0] make_task(input integer bank,input integer id,input integer count,input[63:0] target);
reg[1535:0] t;begin t=0;t[OWNER_EPOCH_BIT+:64]=current_owner_epoch;t[GENERATION_BIT+:64]=current_generation;t[STREAM_GROUP_ID_BIT+:32]=1;t[BANK_ID_BIT+:32]=bank;t[SAMPLE_COUNT_BIT+:32]=count;t[CONFIG_ID_BIT+:32]=11;t[FIR_ID_BIT+:32]=12;t[SOURCE_EPOCH_BIT+:32]=13;t[SOURCE_ROLE_BIT+:32]=1;t[TARGET_GSC_BIT+:64]=target;t[TASK_ID_BIT+:64]=id;t[OUTPUT_DAC_MASK_BIT+:32]=1;make_task=t;end endfunction
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task ck(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
task enqueue(input integer bank,input integer id,input integer count,input[63:0] target);begin submit_task=make_task(bank,id,count,target);submit_valid=1;tick();submit_valid=0;ck(submit_accepted,"queue admission");end endtask
integer samples=0,reads=0,lasts=0;
always @(negedge clk)begin
 if(ram_en)reads=reads+1;
 if(raw_valid&&active_task[TASK_ID_BIT+:64]==1)begin ck(raw_data==64'h1000+samples,"actual RAM sequence");samples=samples+1;if(raw_last)lasts=lasts+1;end
end
initial begin
 tick();rst=0;writes=16'hffff;
 for(integer a=0;a<16;a=a+1)begin write_addr=a;for(integer g=0;g<4;g=g+1)group_data[g*64+:64]=64'h1000+g*256+a;tick();end writes=0;
 enqueue(0,1,4,gsc+80);enqueue(1,2,4,gsc+400);processing_ready=1;
 while(!task_started)tick();ck(active_task[TASK_ID_BIT+:64]==1,"latched full task");current_generation=8;
 while(!token_valid)tick();ck(samples==4&&lasts==1&&token_status==0&&token_consumer==2,"actual last RAM read returns token");
 submit_task=make_task(0,99,4,gsc+400);submit_valid=1;tick();submit_valid=0;
 ck(submit_rejected&&submit_reason==15&&token_valid&&token_generation==7,"duplicate bank submission rejected while real completion token held");
 repeat(5)tick();ck(token_valid&&queued_count==1&&!rejected_valid&&!idle,"token backpressure retains engine and bank reservation");
 token_ready=1;tick();token_ready=0;while(!rejected_valid)tick();ck(reject_reason==4&&!token_valid,"queued generation became stale, no invented return");reject_ready=1;tick();reject_ready=0;
 processing_ready=0;enqueue(1,3,4,gsc+12);repeat(5)tick();ck(rejected_valid&&reject_reason==9&&!token_valid,"queued deadline rechecked while processing blocked");reject_ready=1;tick();reject_ready=0;
 processing_ready=1;enqueue(0,4,8,gsc+80);while(!ram_en)tick();tick();hard_fault=1;#1;ck(!raw_valid&&raw_data==0&&!ram_en,"hard fault immediate output inhibit");while(!token_valid)tick();ck(token_status==10,"canceled actual reader token");token_ready=1;tick();token_ready=0;hard_fault=0;
 enqueue(0,5,8,gsc+80);while(!task_started)tick();current_owner_epoch=current_owner_epoch+1;while(!token_valid)tick();ck(token_status==10&&token_owner_epoch==5,"owner epoch abort preserves old token identity");token_ready=1;tick();token_ready=0;
 drop_response=1;enqueue(0,7,4,gsc+80);while(!token_valid)tick();ck(token_status==11&&!raw_valid,"missing actual fixed-latency RAM response cancels safely");token_ready=1;tick();token_ready=0;drop_response=0;
 binding_valid=0;enqueue(1,6,4,gsc+80);while(!rejected_valid)tick();ck(reject_reason==2&&!token_valid,"UNBOUND never starts reader or creates token");reject_ready=1;tick();reject_ready=0;tick();ck(idle,"all owned dispatcher work drained");
 $display("PASS replay task dispatcher: actual RAM, queued stale/late, fault/epoch cancel, held real token");$finish;
end
initial begin #30000;$fatal(1,"timeout");end
endmodule
