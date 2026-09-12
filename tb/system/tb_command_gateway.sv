`timescale 1ns/1ps
module tb_command_gateway;
 import command_gateway_pkg::*;
 reg ctrl_clk=0,rf_clk=0,rst_n=0;always #5 ctrl_clk=~ctrl_clk;initial begin #0.7;forever #4 rf_clk=~rf_clk;end
 reg [31:0] s_axi_awaddr=0,s_axi_wdata=0,s_axi_araddr=0;reg [3:0] s_axi_wstrb=15;
 reg s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=1,s_axi_arvalid=0,s_axi_rready=1;
 wire s_axi_awready,s_axi_wready,s_axi_bvalid,s_axi_arready,s_axi_rvalid;wire [1:0] s_axi_bresp,s_axi_rresp;wire [31:0] s_axi_rdata;
 reg pdw_available_rf=0,source_event_available_rf=0,rf_fault_available_rf=0;
 wire cmd_valid,irq,result_ready;reg cmd_ready=0,result_valid=0;wire [15:0] cmd_opcode,cmd_words;wire [31:0] cmd_sequence;wire [8191:0] cmd_payload;
 reg [7:0] result_code=0;reg [15:0] result_words=1;reg [8191:0] result_payload=0;
 command_gateway_axi dut(.*);
 task write_word(input [31:0] a,v,input [1:0] expected);begin
  @(negedge ctrl_clk);s_axi_awaddr=a;s_axi_awvalid=1;
  do begin @(posedge ctrl_clk);end while(!s_axi_awready);
  @(negedge ctrl_clk);s_axi_awvalid=0;repeat(2)@(negedge ctrl_clk);
  s_axi_wdata=v;s_axi_wvalid=1;do begin @(posedge ctrl_clk);end while(!s_axi_wready);
  @(negedge ctrl_clk);s_axi_wvalid=0;wait(s_axi_bvalid);if(s_axi_bresp!==expected)$fatal(1,"write response %h",a);@(negedge ctrl_clk);
 end endtask
 reg [31:0] value;
 task read_word(input [31:0] a);begin
  @(negedge ctrl_clk);s_axi_araddr=a;s_axi_arvalid=1;do begin @(posedge ctrl_clk);end while(!s_axi_arready);
  @(negedge ctrl_clk);s_axi_arvalid=0;wait(s_axi_rvalid);if(s_axi_rresp!=0)$fatal(1,"read response");value=s_axi_rdata;@(negedge ctrl_clk);
 end endtask
 function automatic [31:0] crc_word(input [31:0] initial_crc,v);reg [31:0] c;begin c=initial_crc;for(integer k=0;k<32;k=k+1)c=(c>>1)^((c[0]^v[k])?32'h82f63b78:0);crc_word=c;end endfunction
 integer seen=0;always @(posedge rf_clk)if(cmd_valid&&cmd_ready)seen=seen+1;
 initial begin
  repeat(4)@(negedge ctrl_clk);rst_n=1;
  read_word(32'h4020);if(value!=1)$fatal(1,"legacy IRQ enable reset");
  pdw_available_rf=1;repeat(5)@(negedge ctrl_clk);
  read_word(32'h4024);if(value!=2||irq)$fatal(1,"raw PDW masked by default");
  write_word(32'h4020,2,0);if(!irq)$fatal(1,"enable existing PDW level");
  write_word(GW_STATUS,2,0);if(!irq)$fatal(1,"DONE clear lost PDW level");
  write_word(32'h4024,2,2);write_word(32'h4020,16,2);
  s_axi_wstrb=2;write_word(32'h4020,0,0);s_axi_wstrb=15;
  read_word(32'h4020);if(value!=2)$fatal(1,"byte mask corrupted IRQ enable");
  write_word(32'h4020,0,0);if(irq)$fatal(1,"mask PDW");
  write_word(32'h4020,3,0);if(!irq)$fatal(1,"unmask PDW");
  pdw_available_rf=0;repeat(5)@(negedge ctrl_clk);if(irq)$fatal(1,"empty PDW deassert");
  write_word(32'h4020,1,0);
  write_word(GW_OP_LENGTH,32'h00010009,0);write_word(GW_SEQUENCE,55,0);write_word(GW_PAYLOAD,32'h12345678,0);
  write_word(GW_CRC32C,~crc_word(crc_word(crc_word(32'hffffffff,32'h00010009),55),32'h12345678),0);
  write_word(GW_SUBMIT,1,0);wait(cmd_valid);
  write_word(GW_PAYLOAD,32'hffffffff,0);write_word(GW_SEQUENCE,99,0);write_word(GW_SUBMIT,1,2);
  repeat(8)@(negedge rf_clk);if(cmd_opcode!=9||cmd_words!=1||cmd_sequence!=55||cmd_payload[31:0]!=32'h12345678)$fatal(1,"inflight payload changed");
  read_word(GW_STATUS);if(!value[0]||value[1])$fatal(1,"CDC receipt is not completion");
  @(negedge rf_clk);cmd_ready=1;@(negedge rf_clk);cmd_ready=0;repeat(5)@(negedge rf_clk);
  read_word(GW_STATUS);if(!value[0])$fatal(1,"execution completion missing");
  @(negedge rf_clk);result_payload=8192'hdeadbeef;result_valid=1;wait(result_ready);@(negedge rf_clk);result_valid=0;
  wait(irq);read_word(GW_DONE_SEQUENCE);if(value!=55||seen!=1)$fatal(1,"response identity");read_word(GW_RESULT);if(value!=32'hdeadbeef)$fatal(1,"response payload");
  write_word(GW_CRC32C,0,0);write_word(GW_SUBMIT,1,0);wait(irq);read_word(GW_STATUS);if(value[15:8]!=1||value[0]||seen!=1)$fatal(1,"CRC reject before RF execution");
  write_word(GW_OP_LENGTH,32'h01010001,0);write_word(GW_SUBMIT,1,2);write_word(GW_RESULT,0,2);
  write_word(32'h4020,0,0);if(irq)$fatal(1,"DONE mask");
  read_word(32'h4024);if(value!=1)$fatal(1,"masked DONE raw status");
  pdw_available_rf=1;repeat(5)@(negedge ctrl_clk);
  read_word(32'h4024);if(value!=3)$fatal(1,"simultaneous sources");
  write_word(32'h4020,3,0);write_word(GW_STATUS,2,0);
  read_word(32'h4024);if(value!=2||!irq)$fatal(1,"ack only DONE");
  rst_n=0;#1;if(irq)$fatal(1,"hard reset IRQ");
  pdw_available_rf=0;repeat(3)@(negedge ctrl_clk);rst_n=1;
  read_word(32'h4020);if(value!=1||irq)$fatal(1,"hard reset enable");
  source_event_available_rf=1;repeat(5)@(negedge ctrl_clk);
  read_word(GW_IRQ_STATUS);if(value!==4||irq!==0)$fatal(1,"source IRQ default masked");
  write_word(GW_IRQ_ENABLE,4,0);if(irq!==1)$fatal(1,"source IRQ enable");
  write_word(GW_STATUS,2,0);if(irq!==1)$fatal(1,"DONE clear lost source IRQ");
  source_event_available_rf=0;repeat(5)@(negedge ctrl_clk);if(irq!==0)$fatal(1,"source IRQ clear");
  rf_fault_available_rf=1;repeat(5)@(negedge ctrl_clk);
  read_word(GW_IRQ_STATUS);if(value!==8||irq!==0)$fatal(1,"fault IRQ masked");
  write_word(GW_IRQ_ENABLE,8,0);if(!irq)$fatal(1,"fault IRQ enable");
  write_word(GW_STATUS,2,0);if(!irq)$fatal(1,"DONE clears fault IRQ");
  rf_fault_available_rf=0;repeat(5)@(negedge ctrl_clk);if(irq)$fatal(1,"fault IRQ empty");
  $display("PASS command gateway AXI frozen CRC request execution response identity bounds PDW_IRQ mask raw reset");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
