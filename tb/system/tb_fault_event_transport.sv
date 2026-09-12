`timescale 1ns/1ps
module tb_fault_event_transport;
 reg rf_clk=0,ctrl_clk=0,rst_n=0;always #4 rf_clk=~rf_clk;initial begin #1.3;forever #5 ctrl_clk=~ctrl_clk;end
 reg fault_valid=0,normal_valid=0;reg [255:0] fault_snapshot=0;reg [511:0] normal_event=0;
 wire normal_ready;reg latch_head=0,pop=0;reg [3:0] word_index=0;
 wire [31:0] word_data,event_count,dropped_events;wire latched_valid,command_rejected;
 fault_event_transport #(.ADDR_W(1)) dut(.*);
 integer fault_id=0,faults_seen=0,normals_seen=0,fd=0;string output_path;reg [511:0] record_value;
 task ctick;begin @(posedge ctrl_clk);#1;@(negedge ctrl_clk);end endtask
 task send_normal(input integer id);begin
  @(negedge rf_clk);normal_event=0;normal_event[31:0]=32'h10001;normal_event[64+:64]=64'(id);normal_event[416+:32]=32'hffffffff;normal_valid=1;
  do begin @(posedge rf_clk);end while(!normal_ready);
  @(negedge rf_clk);normal_valid=0;
 end endtask
 task fault;begin
  @(negedge rf_clk);fault_id=fault_id+1;
  fault_snapshot={64'(fault_id*4),32'h2c,32'h1c,32'd0,32'(fault_id),32'd3,32'h30001};fault_valid=1;
  @(negedge rf_clk);fault_valid=0;
 end endtask
 task read_record;begin
  while(event_count==0)ctick;
  latch_head=1;ctick;latch_head=0;if(!latched_valid)$fatal(1,"latch");
  for(integer w=15;w>=0;w=w-1)begin word_index=w;#1;record_value[w*32+:32]=word_data;ctick;end
  // A second latch and a second word pass must retain the same queue head.
  latch_head=1;ctick;latch_head=0;
  for(integer w=0;w<16;w=w+1)begin word_index=w;#1;if(word_data!==record_value[w*32+:32])$fatal(1,"snapshot changed");if(fd)$fwrite(fd,"%08x ",word_data);ctick;end
  if(fd)$fwrite(fd,"\n");
  if(record_value[31:0]==32'h10001)begin
   normals_seen=normals_seen+1;if(record_value[64+:64]!=normals_seen)$fatal(1,"normal order");
  end else begin
   if(record_value[31:0]!=32'h40001||record_value[63:32]!=0||record_value[127:96]!=0||record_value[511:384]!=0)$fatal(1,"fault envelope");
   if(record_value[159:128]!=32'h30001||record_value[191:160]!=3||record_value[223:192]!=faults_seen+1||record_value[255:224]!=0||record_value[287:256]!=32'h1c||record_value[319:288]!=32'h2c||record_value[383:320]!=(faults_seen+1)*4)$fatal(1,"first snapshot");
   if(record_value[95:64]==0)$fatal(1,"zero occurrence");faults_seen=faults_seen+record_value[95:64];
  end
  pop=1;ctick;pop=0;if(latched_valid||command_rejected)$fatal(1,"POP");
 end endtask
 initial begin
  if($value$plusargs("OUT=%s",output_path))begin fd=$fopen(output_path,"w");if(!fd)$fatal(1,"file");end
  repeat(4)ctick;rst_n=1;repeat(5)ctick;
  send_normal(1);send_normal(2);send_normal(3);send_normal(4);
  repeat(40)fault;repeat(20)ctick;
  if(event_count!=2||dropped_events!=0||normal_ready)$fatal(1,"full backpressure/drop");
  while(faults_seen<40||normals_seen<4)read_record;
  repeat(30)ctick;if(event_count||dropped_events)$fatal(1,"drain/drop");
  send_normal(99);fault;repeat(12)ctick;latch_head=1;ctick;latch_head=0;
  rst_n=0;fault_valid=0;normal_valid=0;repeat(4)ctick;rst_n=1;repeat(20)ctick;
  if(event_count||latched_valid||dropped_events)$fatal(1,"coordinated reset");
  send_normal(5);read_record;
  if(normals_seen!=5||faults_seen!=40)$fatal(1,"counts");
  if(fd)$fclose(fd);
  $display("PASS fault event transport full CDC snapshot fault_count=%0d normals=%0d zero_drop reset",faults_seen,normals_seen);$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
