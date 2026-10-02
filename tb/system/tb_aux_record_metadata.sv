`timescale 1ns/1ps
module tb_aux_record_metadata;
reg clk=0;always #4 clk=~clk;
reg rst=1,request_valid=0,result_ready=0,bound=1;
reg [1023:0] template_header=0;
reg [31:0] metadata_id=32'hfedcba98,epoch_id=9,source_epoch=7,h_calibration_id=11,v_calibration_id=12,config_id=13,fir_id=14;
reg [63:0] capture_id=64'h123456789abcdef0,owner_epoch=64'habcdef0123456789,generation=64'h9876543210abcdef,tx_token=64'hfedcba9876543210,start_seq=1234,start_gsc=5678;
reg [14:0] sample_count=16384;
reg [7:0] source_role=3,status=0;
reg [3:0] bank=2;
wire request_ready,result_valid,rejected;
wire [1023:0] header_data;wire [767:0] metadata_data;
aux_record_metadata dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
reg [1791:0] held;integer f;string vector_path;
initial begin
 tick();rst=0;template_header[74*8+:16]=7;template_header[68*8+:32]=4;template_header[80*8+:32]=99;
 request_valid=1;tick();request_valid=0;
 if(!result_valid||rejected||header_data[92*8+:32]!=metadata_id||header_data[16*8+:64]!=capture_id||header_data[80*8+:32]!=0||header_data[116*8+:32]!=32'h08038804||header_data[8*8+:32]!=131216)$fatal(1,"AUX header mapping");
 if(!$value$plusargs("VECTOR=%s",vector_path))vector_path="aux_metadata_vector.txt";
 f=$fopen(vector_path,"w");if(!f)$fatal(1,"vector output open");$fdisplay(f,"%h",metadata_data);$fdisplay(f,"%h",header_data);$fclose(f);
 held={header_data,metadata_data};capture_id=1;tx_token=2;metadata_id=3;status=31;
 repeat(5)begin tick();if({header_data,metadata_data}!==held||request_ready)$fatal(1,"pair stall");end
 result_ready=1;request_valid=1;tick();request_valid=0;result_ready=0;
 if(!result_valid||header_data[68*8+:32]!=(4|1|256|128|512|1024)||metadata_data[90*8+:8]!=31)$fatal(1,"replacement/error mapping");
 result_ready=1;tick();result_ready=0;
 bound=0;request_valid=1;tick();if(!rejected||result_valid)$fatal(1,"unbound admitted");
 bound=1;metadata_id=0;tick();if(!rejected||result_valid)$fatal(1,"zero metadata id");
 metadata_id=1;source_role=1;tick();if(!rejected||result_valid)$fatal(1,"role");
 source_role=2;bank=4;tick();if(!rejected||result_valid)$fatal(1,"bank truncation");
 bank=0;status=32;tick();if(!rejected||result_valid)$fatal(1,"status reserved");
 status=0;sample_count=0;tick();if(!rejected||result_valid)$fatal(1,"zero count");
 sample_count=1;tick();if(rejected||!result_valid)$fatal(1,"minimum count");
 rst=1;tick();if(result_valid)$fatal(1,"reset stale pair");
 $display("PASS AUX_METADATA paired header/sidecar, full identities, backpressure, replacement, rejects and reset");$finish;
end
initial begin #10000;$fatal(1,"timeout");end
endmodule
