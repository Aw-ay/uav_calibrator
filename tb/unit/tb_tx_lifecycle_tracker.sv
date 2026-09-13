`timescale 1ns/1ps
module tb_tx_lifecycle_tracker;
 reg clk=0,rst=1;always #4 clk=~clk;
 reg start_valid=0,source_done=0,source_drained=0,tail_empty=0,time_valid=1,require_sink_ack=0;
 reg [31:0] source=1,command_sequence=7,config_id=9,cancel_reason=0;
 reg [63:0] gsc=0,sink_ack_token=0;
 reg sink_fence_ready=0,sink_ack_valid=0,event_ready=0;
 wire start_ready,start_rejected,busy,sink_fence_valid,protocol_error,event_valid;
 wire [63:0] sink_fence_token;wire [511:0] event_data;
 tx_lifecycle_tracker dut(.*);
 always @(posedge clk)if(!rst)gsc<=gsc+4;
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task begin_task(input bit require_ack);begin require_sink_ack=require_ack;source_done=0;source_drained=0;tail_empty=0;cancel_reason=0;start_valid=1;tick();start_valid=0;if(!busy)$fatal(1,"start");end endtask
 integer record_file;string record_path;reg record_seen=0;
 initial begin if(!$value$plusargs("OUT=%s",record_path))record_path="tx_lifecycle_records.txt";record_file=$fopen(record_path,"w");end
 always @(posedge clk)begin
  if(rst||event_valid!==1'b1)record_seen<=0;
  else if(!record_seen)begin for(integer w=0;w<16;w++)$fwrite(record_file,"%08x%s",event_data[w*32+:32],w==15?"\n":" ");record_seen<=1;end
 end
 reg [511:0] saved;
 initial begin
  tick();rst=0;begin_task(0);
  tail_empty=1;tick();if(event_valid)$fatal(1,"PRI gap is not source done");
  source_done=1;tick();source_done=0;if(event_valid)$fatal(1,"not source drained");
  source_drained=1;tail_empty=0;tick();if(event_valid)$fatal(1,"tail still live");
  tail_empty=1;tick();tick();if(!event_valid||event_data[63:32]!=3||event_data[255:192]!=1)$fatal(1,"digital retire");
  saved=event_data;repeat(4)begin tick();if(event_data!==saved||!event_valid||start_ready)$fatal(1,"stalled record");end
  event_ready=1;tick();event_ready=0;
  begin_task(1);source_done=1;source_drained=1;tail_empty=1;tick();source_done=0;
  if(!sink_fence_valid||sink_fence_token!=2||event_valid)$fatal(1,"sink fence");
  sink_ack_token=2;sink_ack_valid=1;tick();sink_ack_valid=0;if(!protocol_error||event_valid)$fatal(1,"ack before fence acceptance");
  sink_fence_ready=1;tick();sink_fence_ready=0;
  sink_ack_valid=1;sink_ack_token=1;tick();sink_ack_valid=0;if(!protocol_error||event_valid)$fatal(1,"wrong token");
  cancel_reason=2;tick();cancel_reason=1;tick();
  sink_ack_valid=1;sink_ack_token=2;tick();sink_ack_valid=0;tick();
  if(!event_valid||event_data[63:32]!=7||event_data[127:96]!=2)$fatal(1,"sink confirmation/cancel");
  if(event_data[447:384]<event_data[383:320])$fatal(1,"retire before drain");
  event_ready=1;tick();event_ready=0;
  begin_task(0);time_valid=0;tick();time_valid=1;source_done=1;source_drained=1;tail_empty=1;tick();tick();
  if(!event_valid||event_data[63:32]!=1||event_data[447:256]!=0||event_data[511:448]!=0)$fatal(1,"invalid time/reserved");
  tick();rst=1;tick();rst=0;tick();if(event_valid||busy||sink_fence_valid)$fatal(1,"reset");
  $fclose(record_file);$display("PASS TX lifecycle tracker source/tail fence token cancellation timestamps stall reset");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
