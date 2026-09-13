`timescale 1ns/1ps
module tb_replay_drain_system;
reg profile_commit=0;wire profile_ready,profile_accepted,profile_rejected,dsp_busy,dsp_done,dsp_cancelled,source_ready,out_valid,out_qualified,arithmetic_saturated;
wire [63:0] out_hv;wire [31:0] table_version;
reg [63:0] shadow_dc=0;reg [143:0] shadow_matrix=0;
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
calibrator_replay_system dut(.profile_commit(profile_commit),.shadow_cal_valid(2'b11),.shadow_dc(shadow_dc),.shadow_gain({18'd0,18'd65536,18'd0,18'd65536}),.shadow_matrix(shadow_matrix),.shadow_fd_phase(8'd0),.shadow_fd_version(32'h9d1dc12a),.shadow_rx_cal_id(32'd101),.shadow_target_matrix_id(32'd102),.shadow_doppler_phase_id(32'd103),.phase_valid(1'b1),.phase_i(18'sd65536),.phase_q(18'sd0),.profile_ready(profile_ready),.profile_accepted(profile_accepted),.profile_rejected(profile_rejected),.source_ready(source_ready),.dsp_busy(dsp_busy),.dsp_done(dsp_done),.dsp_cancelled(dsp_cancelled),.out_valid(out_valid),.out_hv(out_hv),.out_qualified(out_qualified),.arithmetic_saturated(arithmetic_saturated),.table_version(table_version),.clk(clk),.rst(rst),.submit_valid(submit_valid),.submit_task(submit_task),.submit_accepted(submit_accepted),.submit_rejected(submit_rejected),.submit_reason(submit_reason),
.lookup_valid(lookup_valid),.lookup_task(lookup_task),.lookup_ready(lookup_ready),.gsc(gsc),.current_owner_epoch(current_owner_epoch),.current_generation(current_generation),.current_config_id(32'd11),.current_fir_id(32'd12),.current_source_epoch(32'd13),
.bank_frozen(1'b1),.data_ready(1'b1),.qualified(1'b1),.lease_pinned(1'b1),.source_stable(1'b1),.allow_aux_replay(1'b0),.task_profiles_valid(1'b1),.guard_clear(1'b1),.planned_slot_clear(1'b1),.rf_safe(1'b1),.binding_valid(binding_valid),.resources_ready(1'b1),.time_valid(1'b1),.clock_ok(1'b1),.latency_validated(1'b1),.fractional_supported(1'b0),.downstream_latency_ticks(64'd168),.hard_fault(hard_fault),.abort_request(abort_request),
.rejected_valid(rejected_valid),.rejected_task(rejected_task),.reject_reason(reject_reason),.reject_ready(reject_ready),.task_started(task_started),.active_task(active_task),.raw_valid(raw_valid),.raw_data(raw_data),.raw_last(raw_last),.ram_en(ram_en),.ram_addr(ram_addr),.ram_group(ram_group),.ram_bank(ram_bank),.ram_response_valid(ram_response_valid),.ram_data(ram_data),
.actual_start(actual_start),.actual_finish(actual_finish),.actual_start_gsc(actual_start_gsc),.actual_finish_gsc(actual_finish_gsc),.token_valid(token_valid),.token_ready(token_ready),.token_owner_epoch(token_owner_epoch),.token_generation(token_generation),.token_group(token_group),.token_bank(token_bank),.token_consumer(token_consumer),.token_status(token_status),.queued_count(queued_count),.idle(idle));
// Actual reader token and FD/Target output observation; no forced internals.
wire observer_ready,observer_rejected,observer_error,observed_valid;
wire [1535:0] observed_context;wire [7:0] observed_status;integer observed_count=0;
replay_drain_observer observer(.clk(clk),.rst(rst),.task_started(task_started),.task_context(active_task),
 .reader_retired(token_valid&&token_ready),.reader_status(token_status),.dsp_busy(dsp_busy),.dsp_out_valid(out_valid),
 .drained_ready(1'b1),.start_ready(observer_ready),.start_rejected(observer_rejected),.protocol_error(observer_error),
 .drained_valid(observed_valid),.drained_context(observed_context),.drained_status(observed_status));
always @(posedge clk)if(!rst)begin
 if(observer_rejected||observer_error)$fatal(1,"observer protocol mismatch");
 if(observed_valid)begin
  if(dsp_busy||out_valid)$fatal(1,"real DSP still occupied at source retirement");
  if(observed_context[TASK_ID_BIT+:64]!=observed_count+1)$fatal(1,"actual replay identity");
  if(observed_context[OWNER_EPOCH_BIT+:64]!=((observed_count==3)?6:5))$fatal(1,"retained epoch changed");
  if(observed_status!=((observed_count==1)?11:((observed_count==3)?10:0)))$fatal(1,"actual reader result");
  observed_count=observed_count+1;
 end
end
function automatic[1535:0] make_task(input integer bank,input integer id,input integer count,input[63:0] target);
reg[1535:0] t;begin t=0;t[OWNER_EPOCH_BIT+:64]=current_owner_epoch;t[GENERATION_BIT+:64]=current_generation;t[STREAM_GROUP_ID_BIT+:32]=1;t[BANK_ID_BIT+:32]=bank;t[SAMPLE_COUNT_BIT+:32]=count;t[CONFIG_ID_BIT+:32]=11;t[FIR_ID_BIT+:32]=12;t[SOURCE_EPOCH_BIT+:32]=13;t[SOURCE_ROLE_BIT+:32]=1;t[TARGET_GSC_BIT+:64]=target;t[TASK_ID_BIT+:64]=id;t[OUTPUT_DAC_MASK_BIT+:32]=1;t[RX_CAL_ID_BIT+:32]=101;t[TARGET_MATRIX_ID_BIT+:32]=102;t[DOPPLER_PHASE_ID_BIT+:32]=103;make_task=t;end endfunction
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task ck(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
task enqueue(input integer bank,input integer id,input integer count,input[63:0] target);begin submit_task=make_task(bank,id,count,target);submit_valid=1;tick();submit_valid=0;ck(submit_accepted,"queue admission");end endtask

integer received=0;reg checking=1;reg[63:0] expected;
always @(posedge clk)begin #1;
 if(out_valid&&checking)begin
  expected=(received>=31&&received<35)?64'h1000+received-31:64'd0;
  if(received==31)ck(gsc-4==active_task[TARGET_GSC_BIT+:64],"DSP-only reference GSC includes11 register stages plus31 sample delay");
  ck(out_qualified&&out_hv===expected,"RAM through RXCAL FD63 identity matrix exact sample");received=received+1;
 end
end
initial begin
 shadow_matrix[0+:18]=65536;shadow_matrix[108+:18]=65536;
 tick();rst=0;writes=16'hffff;
 for(integer a=0;a<16;a=a+1)begin write_addr=a;for(integer g=0;g<4;g=g+1)group_data[g*64+:64]=64'h1000+g*256+a;tick();end writes=0;
 profile_commit=1;tick();profile_commit=0;#1;ck(profile_accepted&&source_ready,"explicit immutable profile loaded");
 enqueue(0,1,4,gsc+240);while(!task_started)tick();
 shadow_dc=64'h100;profile_commit=1;tick();profile_commit=0;#1;ck(profile_rejected,"profile cannot change while reader waits for target");shadow_dc=0;
 while(!token_valid)tick();ck(token_status==0&&dsp_busy,"RAW completion precedes FD tail completion");token_ready=1;tick();token_ready=0;ck(!idle&&dsp_busy,"RAW token does not release DSP processing ownership");
 while(!dsp_done)tick();ck(received==66&&!dsp_busy,"4 actual samples plus62 zero flush and full register drain");checking=0;
 submit_task=make_task(1,9,4,gsc+240);submit_task[RX_CAL_ID_BIT+:32]=999;submit_valid=1;tick();submit_valid=0;
 while(!rejected_valid)tick();ck(reject_reason==4&&!token_valid&&!ram_en,"task profile ID mismatch never reads RAM");reject_ready=1;tick();reject_ready=0;
 enqueue(0,2,8,gsc+240);while(!raw_valid)tick();drop_response=1;
 while(!token_valid)tick();ck(token_status==11,"actual underflow token");token_ready=1;tick();token_ready=0;drop_response=0;
 for(integer n=0;n<100&&dsp_busy;n=n+1)tick();ck(!dsp_busy&&dsp_cancelled&&!source_ready&&out_hv==0,"underflow without raw_last cancels and drains DSP");
 profile_commit=1;tick();profile_commit=0;#1;ck(profile_accepted&&!dsp_cancelled,"fresh validated profile required after cancel");
 enqueue(0,3,2,gsc+240);while(!token_valid)tick();token_ready=1;tick();token_ready=0;ck(dsp_busy,"tail still active after last RAW");current_owner_epoch=current_owner_epoch+1;#1;ck(!out_valid&&out_hv==0,"epoch change also cancels active post-RAW tail");
 for(integer n=0;n<100&&dsp_busy;n=n+1)tick();ck(!dsp_busy&&dsp_cancelled&&idle,"epoch cancel drains full wrapper");
 repeat(5)tick();ck(observed_count==3,"three prior retirements");
 profile_commit=1;tick();profile_commit=0;ck(profile_accepted,"reprepare before early cancel");
 enqueue(0,4,2,gsc+400);while(!task_started)tick();abort_request=1;
 while(!token_valid)tick();ck(token_status==10&&!dsp_busy&&!raw_valid,"cancel before first sample has no DSP done");
 token_ready=1;tick();token_ready=0;abort_request=0;
 repeat(5)tick();ck(observed_count==4,"all actual replay tasks observed after drain");
 $display("PASS replay drain system actual RAM FD63 Target normal underflow epoch and before-first-sample cancellation");
 $display("PASS calibrator replay system: real RAM RXCAL FD63 target samples, separate tails, underflow and epoch cancellation");$finish;
end
initial begin #50000;$fatal(1,"timeout");end
endmodule

