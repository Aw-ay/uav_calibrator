`timescale 1ns/1ps
module tb_capture_replay_binding;
 import replay_control_layout_pkg::*;
 reg clk=0,rst=1;always #4 clk=~clk;
 reg [1535:0] lookup_task=0,active_task=0;
 reg active=0;reg [63:0] owner_epoch=5;
 reg [15:0] frozen=0,qualified=0,replay_leased=0;
 reg [1023:0] generation=0,pulse_id=0,start_seq=0;reg [239:0] sample_count=0;
 wire [63:0] current_generation;wire bank_frozen,data_ready,bank_qualified,lease_pinned;
 reg ram_en=0;reg [31:0] ram_group=1,ram_bank=0;reg [13:0] ram_addr=0;
 wire [15:0] replay_enable;wire [223:0] replay_address;
 reg [1023:0] replay_data=0;reg [15:0] replay_valid=0;wire ram_response_valid;wire [63:0] ram_data;
 reg token_valid=0;reg [63:0] token_owner_epoch=5,token_generation=7;
 reg [31:0] token_group=1,token_bank=0,token_consumer=2;
 wire token_ready,ack_replay;wire [3:0] ack_replay_bank;wire [63:0] ack_replay_epoch,ack_replay_generation;
 wire [31:0] rejected_tokens;
 capture_replay_binding dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task ck(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 initial begin
 tick();rst=0;
 for(integer n=0;n<16;n=n+1)begin
  generation[n*64+:64]=7+n;pulse_id[n*64+:64]=100+n;start_seq[n*64+:64]=16381;sample_count[n*15+:15]=7;
  frozen[n]=1;qualified[n]=1;replay_leased[n]=1;replay_data[n*64+:64]=1000+n;
 end
 lookup_task[OWNER_EPOCH_BIT+:64]=5;lookup_task[GENERATION_BIT+:64]=7;lookup_task[PULSE_ID_BIT+:64]=100;
 lookup_task[START_SEQ_BIT+:64]=16381;lookup_task[START_PTR_BIT+:32]=16381;lookup_task[SAMPLE_COUNT_BIT+:32]=7;
 lookup_task[STREAM_GROUP_ID_BIT+:32]=1;#1;ck(data_ready&&lease_pinned&&current_generation==7,"valid actual bank context");
 lookup_task[PULSE_ID_BIT+:64]=99;#1;ck(!data_ready,"wrong pulse");lookup_task[PULSE_ID_BIT+:64]=100;
 lookup_task[SAMPLE_COUNT_BIT+:32]=8;#1;ck(!data_ready,"read beyond frozen length");lookup_task[SAMPLE_COUNT_BIT+:32]=7;
 replay_leased[0]=0;#1;ck(!lease_pinned,"frozen is not replay ownership");replay_leased[0]=1;
 lookup_task[STREAM_GROUP_ID_BIT+:32]=0;#1;ck(!data_ready&&!bank_frozen,"zero group rejected");lookup_task[STREAM_GROUP_ID_BIT+:32]=1;
 active_task=lookup_task;active=1;lookup_task[STREAM_GROUP_ID_BIT+:32]=4;lookup_task[BANK_ID_BIT+:32]=3;#1;ck(current_generation==7,"active reader identity independent of next queue head");active=0;
 for(integer n=0;n<16;n=n+1)begin
  ram_group=n/4+1;ram_bank=n%4;ram_addr=123;ram_en=1;#1;ck(replay_enable==(16'b1<<n)&&replay_address[n*14+:14]==123,"group bank read mapping");
  tick();ram_en=0;ram_group=0;replay_valid=16'b1<<n;#1;ck(ram_response_valid&&ram_data==1000+n,"response uses captured request index");tick();replay_valid=0;
 end
 token_valid=1;token_generation=6;#1;ck(token_ready&&!ack_replay,"stale token consumed without release");tick();token_valid=0;ck(rejected_tokens==1,"stale token observable");
 token_generation=7;token_valid=1;#1;ck(ack_replay&&ack_replay_bank==0&&ack_replay_epoch==5&&ack_replay_generation==7,"valid token releases actual lease");tick();token_valid=0;replay_leased[0]=0;
 token_valid=1;#1;ck(!ack_replay,"duplicate token cannot release twice");tick();token_valid=0;
 token_consumer=1;token_bank=1;token_generation=8;token_valid=1;#1;ck(!ack_replay,"wrong consumer");tick();
 ck(rejected_tokens==3,"all invalid tokens counted");$display("PASS capture replay binding actual ownership identity bounds response routing tokens");$finish;
 end
endmodule
