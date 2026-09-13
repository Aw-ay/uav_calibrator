`timescale 1ns/1ps
module tb_tx_task_lifecycle;
 reg clk=0;always #4 clk=~clk;
 reg rst=1,dds_started=0,awg_started=0,replay_started=0,dds_done=0,awg_done=0,generated_drained=1;
 reg replay_reader_retired=0,replay_dsp_busy=0,replay_out_valid=0,replay_cancelled=0;
 reg [7:0] replay_reader_status=0;reg [1535:0] replay_context=0;
 reg [63:0] gsc=0,sink_ack_token=0;always @(posedge clk)if(rst)gsc<=0;else gsc<=gsc+4;
 reg time_valid=1,tail_empty=1,require_sink_ack=1,sink_fence_ready=0,sink_ack_valid=0,event_ready=0;
 reg [31:0] command_sequence=77,config_id=9,cancel_reason=0;
 wire admission_ready,protocol_error,sink_fence_valid,event_valid;wire [63:0] sink_fence_token;wire [511:0] event_data;
 tx_task_lifecycle dut(.*);
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 integer rows=0,errors=0,fd;string path;reg [511:0] held;
 always @(posedge clk)if(!rst)begin
  if(protocol_error)errors=errors+1;
  if(event_valid&&event_ready)begin
   for(integer w=0;w<16;w=w+1)$fwrite(fd,"%08x ",event_data[w*32+:32]);$fwrite(fd,"\n");
   if(rows==0||rows==3)begin
    if(event_data[31:0]!=32'h60001||event_data[64+:64]!=((rows==0)?1:3)||event_data[128+:64]!=64'hfedcba9876543210)$fatal(1,"identity order/token/full64");
   end else begin
    if(event_data[31:0]!=32'h50001||event_data[192+:64]!=((rows==1)?1:((rows==2)?2:3)))$fatal(1,"shared retirement token");
    if(event_data[64+:32]!=((rows==2)?1:3)||event_data[128+:32]!=((rows==2)?77:0))$fatal(1,"source/command identity");
    if(event_data[32+:32]!=((rows==1)?7:3)||event_data[96+:32]!=((rows==4)?4:0))$fatal(1,"retirement flags/cause");
   end
   rows=rows+1;
  end
 end
 task start_replay;begin
  if(!admission_ready)$fatal(1,"replay admission unavailable");replay_started=1;tick;replay_started=0;
 end endtask
 initial begin
  if(!$value$plusargs("OUT=%s",path))path="tx_task_records.txt";fd=$fopen(path,"w");if(!fd)$fatal(1,"fixture");
  repeat(3)tick;rst=0;tick;
  replay_context[768+:64]=64'hfedcba9876543210;replay_context[320+:32]=1;
  start_replay;repeat(5)tick;if(!event_valid||event_data[31:0]!=32'h60001||admission_ready)$fatal(1,"identity first");held=event_data;
  dds_started=1;tick;dds_started=0;if(!protocol_error)$fatal(1,"overlapping actual start not diagnosed");
  repeat(5)begin tick;if(event_data!==held||sink_fence_valid)$fatal(1,"stalled identity changed or premature sink fence");end
  replay_reader_retired=1;replay_dsp_busy=1;tail_empty=0;tick;replay_reader_retired=0;
  event_ready=1;repeat(5)tick;replay_dsp_busy=0;repeat(5)tick;
  if(rows!=1||sink_fence_valid||admission_ready)$fatal(1,"TX tail not respected");tail_empty=1;
  while(!sink_fence_valid)tick;sink_fence_ready=1;tick;
  sink_ack_token=99;sink_ack_valid=1;tick;sink_ack_valid=0;tick;if(rows!=1||admission_ready)$fatal(1,"wrong ACK retired");
  sink_ack_token=1;sink_ack_valid=1;tick;sink_ack_valid=0;while(rows<2)tick;
  while(!admission_ready)tick;require_sink_ack=0;dds_started=1;generated_drained=0;tick;dds_started=0;
  repeat(3)tick;dds_done=1;tick;dds_done=0;repeat(3)tick;if(rows!=2)$fatal(1,"generated source not drained");
  generated_drained=1;while(rows<3)tick;while(!admission_ready)tick;
  start_replay;replay_reader_status=11;replay_reader_retired=1;tick;replay_reader_retired=0;
  while(rows<5)tick;repeat(3)tick;if(errors!=2)$fatal(1,"protocol error accounting %0d",errors);
  $fclose(fd);$display("PASS shared TX lifecycle replay identity ordering tail sink ACK DDS token cancellation admission");$finish;
 end
 initial begin #30000;$fatal(1,"watchdog rows=%0d",rows);end
endmodule
