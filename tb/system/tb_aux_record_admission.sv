`timescale 1ns/1ps
module tb_aux_record_admission;
reg clk=0;always #4 clk=~clk;reg rst=1,request_valid=0,result_ready=0,bound=1,block_new_work=0;
reg [1023:0] template_header=0;
reg [31:0] epoch_id=9,source_epoch=7,h_calibration_id=11,v_calibration_id=12,config_id=13,fir_id=14;
reg [63:0] capture_id=64'h123456789abcdef0,owner_epoch=10,generation=20,tx_token=64'hfedcba9876543210,start_seq=1234,start_gsc=5678;
reg [14:0] requested_count=8;
reg [7:0] source_role=3,status=0;reg [3:0] bank=2;
reg [63:0] live_owner_epoch=10;
reg [3:0] pending=4'b0100,frozen=0,truncated=0;
reg [255:0] bank_generation=0,bank_capture_id=0,bank_start_seq=0;
reg [59:0] bank_sample_count=0;
wire request_ready,result_valid,rejected,capacity_available,id_exhausted;wire [31:0] reject_count;
wire [1023:0] header_data;wire [767:0] metadata_data;
aux_record_admission #(.MAX_METADATA_ID(3)) dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task submit(input bit good);begin request_valid=1;tick();request_valid=0;if(rejected===good||result_valid!==good)$fatal(1,"admission expected=%b rejected=%b valid=%b",good,rejected,result_valid);end endtask
task pop;begin result_ready=1;tick();result_ready=0;end endtask
reg [1791:0] held;
initial begin
 bank_generation[128+:64]=20;bank_capture_id[128+:64]=capture_id;bank_start_seq[128+:64]=1234;bank_sample_count[30+:15]=8;
 tick();rst=0;
 block_new_work=1;submit(0);block_new_work=0;
 live_owner_epoch=11;submit(0);live_owner_epoch=10;
 bank_generation[128+:64]=21;submit(0);bank_generation[128+:64]=20;
 bank_capture_id[128+:64]=1;submit(0);bank_capture_id[128+:64]=capture_id;
 bank_start_seq[128+:64]=1235;submit(0);bank_start_seq[128+:64]=1234;
 bank_sample_count[30+:15]=9;submit(0);bank_sample_count[30+:15]=8;
 pending=0;submit(0);pending=4;
 bound=0;submit(0);bound=1;
 bank=6;submit(0);bank=2;
 status=8;submit(0);status=0;
 submit(1);if(metadata_data[8*8+:32]!=1||header_data[92*8+:32]!=1)$fatal(1,"rejections consumed IDs");
 held={header_data,metadata_data};epoch_id=100;live_owner_epoch=11;bank_sample_count[30+:15]=2;
 repeat(4)begin tick();if({header_data,metadata_data}!==held||capacity_available||request_ready)$fatal(1,"stall changed record");end
 pop();live_owner_epoch=10;bank_sample_count[30+:15]=5;truncated=4;
 submit(1);if(header_data[64*8+:32]!=5||header_data[12*8+:32]!=40||metadata_data[84*8+:32]!=5||metadata_data[90*8+:8]!=16||metadata_data[8*8+:32]!=2||metadata_data[12*8+:32]!=100)$fatal(1,"actual truncated length or ID epoch reuse");
 pop();truncated=0;bank_sample_count[30+:15]=8;epoch_id=9;
 submit(1);if(metadata_data[8*8+:32]!=3||!id_exhausted||capacity_available)$fatal(1,"last ID allocation");pop();
 submit(0);if(!id_exhausted||capacity_available||reject_count!=11)$fatal(1,"exhaustion or rejection count");
 $display("PASS AUX_ADMISSION live ownership, actual truncated length, stable pair, monotonic IDs and exhaustion");$finish;
end
initial begin #10000;$fatal(1,"timeout");end
endmodule
