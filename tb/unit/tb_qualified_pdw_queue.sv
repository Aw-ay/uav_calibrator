`timescale 1ns/1ps
module tb_qualified_pdw_queue;
 import calibrator_contract_pkg::*;
 import capture_event_pkg::*;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,in_valid=0,pop_valid=0;reg [63:0] pop_token=0;
 reg [255:0] event_key=0;reg [1023:0] event_header=0;
 reg [511:0] event_stats=0;reg [191:0] event_peaks=0;reg [15:0] post_samples=4;
 wire [31:0] count,dropped;wire [63:0] head_token;wire [511:0] head_data;wire pop_ok;
 qualified_pdw_queue #(.PRE_SAMPLES(3),.ADDR_W(1)) dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task send(input [63:0] id);begin event_key[255:192]=id;in_valid=1;tick();in_valid=0;tick();end endtask
 reg [511:0] held;reg [63:0] token;
 initial begin
  tick();rst=0;event_key={64'd11,64'd8,64'd99,64'd7};
  event_header[FRAME_CONFIG_ID_OFFSET*8+:32]=7;
  event_header[FRAME_RANGE_ID_OFFSET*8+:8]=2;
  event_header[FRAME_GSC_FIRST_OFFSET*8+:64]=100;
  event_header[FRAME_SAMPLE_COUNT_OFFSET*8+:32]=10;
  event_stats[290:276]=10;event_stats[299:297]=7;
  event_stats[46+:46]=1234;event_stats[4*46+:46]=5678;
  event_peaks[32+:32]=100;event_peaks[4*32+:32]=200;
  send(11);if(count!=1||head_token!=1)$fatal(1,"first queue entry");
  if(head_data[31:0]!=EVENT_CAPTURE_TAG||head_data[63:32]!=31||head_data[64+:64]!=11||head_data[128+:64]!=8||head_data[192+:32]!=7)$fatal(1,"identity/flags");
  if(head_data[224+:64]!=112||head_data[288+:32]!=12||head_data[320+:32]!=200||head_data[352+:64]!=6912||head_data[416+:32]!=2||head_data[448+:64]!=0)$fatal(1,"selected measurements");
  held=head_data;token=head_token;send(12);send(13);
  if(count!=2||dropped!=1||head_data!==held||head_token!=token)$fatal(1,"full queue must preserve head and count drop");
  pop_token=99;pop_valid=1;#1;if(pop_ok)$fatal(1,"wrong token accepted");tick();pop_valid=0;
  if(count!=2||head_data!==held)$fatal(1,"wrong pop changed queue");
  event_key[255:192]=14;in_valid=1;tick();in_valid=0;
  pop_token=token;pop_valid=1;#1;if(!pop_ok)$fatal(1,"correct token rejected");tick();pop_valid=0;
  if(count!=2||dropped!=1||head_data[64+:64]!=12||head_token!=2)$fatal(1,"full queue simultaneous pop/push");
  pop_token=2;pop_valid=1;tick();pop_valid=0;
  if(count!=1||head_data[64+:64]!=14||head_token!=3)$fatal(1,"replacement ordering");
  pop_token=3;pop_valid=1;tick();pop_valid=0;if(count||head_data||head_token)$fatal(1,"empty zero snapshot");
  event_stats[295]=1;event_header[FRAME_SAMPLE_COUNT_OFFSET*8+:32]=6;event_stats[290:276]=6;
  send(14);if(head_data[63:32]!=17||head_data[288+:32]!=0||head_data[320+:32]!=0||head_data[352+:64]!=0)$fatal(1,"invalid widths/stats falsely known");
  pop_token=head_token;pop_valid=1;tick();pop_valid=0;
  event_stats[295]=0;event_stats[290:276]=10;event_header[FRAME_SAMPLE_COUNT_OFFSET*8+:32]=10;
  event_header[FRAME_GSC_FIRST_OFFSET*8+:64]=64'hfffffffffffffffc;
  send(16);if(head_data[63:32]!=30||head_data[224+:64]!=0)$fatal(1,"GSC overflow falsely valid");
  rst=1;tick();if(count||dropped||head_token)$fatal(1,"hard reset flush");
  $display("PASS qualified PDW queue exact values overflow stable peek token invalid flags reset");$finish;
 end
endmodule
