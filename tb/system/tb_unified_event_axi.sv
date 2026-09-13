`timescale 1ns/1ps
module tb_unified_event_axi;
reg ctrl_clk=0,rf_clk=0,rst_n=0,rf_run=1;
always #5 ctrl_clk=~ctrl_clk; always #4 if(rf_run)rf_clk=~rf_clk;
reg [31:0] s_axi_awaddr=0,s_axi_wdata=0,s_axi_araddr=0;
reg [3:0] s_axi_wstrb=15;
reg s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=0,s_axi_arvalid=0,s_axi_rready=0;
wire s_axi_awready,s_axi_wready,s_axi_bvalid,s_axi_arready,s_axi_rvalid;
wire [1:0] s_axi_bresp,s_axi_rresp; wire [31:0] s_axi_rdata;
reg rf_safe_boundary=0,calibration_valid=0; reg [31:0] fault_set=0;
wire [31:0] active_mode,active_config_id,active_pre,active_post,active_max_pulse,active_eop_hold,active_detector_latency;
wire armed,tx_enable,irq; wire [63:0] gsc;
reg rf_event_valid=0;reg [511:0] rf_event_data=0;
wire rf_event_ready;wire [31:0] rf_event_dropped;
reg rf_fault_valid=0; reg [255:0] rf_fault_snapshot=0;
csr_control_axi #(.UNIFIED_EVENTS(1),.EVENT_ADDR_W(1)) dut(.*);
import calibrator_contract_pkg::*;
task aw(input [31:0] a); begin @(negedge ctrl_clk);s_axi_awaddr=a;s_axi_awvalid=1; do @(posedge ctrl_clk);while(!s_axi_awready);@(negedge ctrl_clk);s_axi_awvalid=0;end endtask
task wd(input [31:0] d,input [3:0] st);begin @(negedge ctrl_clk);s_axi_wdata=d;s_axi_wstrb=st;s_axi_wvalid=1;do @(posedge ctrl_clk);while(!s_axi_wready);@(negedge ctrl_clk);s_axi_wvalid=0;end endtask
task br(input [1:0] expected);begin wait(s_axi_bvalid);repeat(3)begin @(negedge ctrl_clk);if(!s_axi_bvalid || s_axi_bresp!==expected)$fatal(1,"B response");end s_axi_bready=1;@(negedge ctrl_clk);s_axi_bready=0;end endtask
task wr(input [31:0] a,d,input [3:0] st,input [1:0] e);begin aw(a);repeat(2)@(negedge ctrl_clk);wd(d,st);br(e);end endtask
task rd(input [31:0] a,expected,input [1:0] resp);begin @(negedge ctrl_clk);s_axi_araddr=a;s_axi_arvalid=1;do @(posedge ctrl_clk);while(!s_axi_arready);@(negedge ctrl_clk);s_axi_arvalid=0;wait(s_axi_rvalid);repeat(3)begin @(negedge ctrl_clk);if(s_axi_rdata!==expected || s_axi_rresp!==resp || !s_axi_rvalid)$fatal(1,"R a=%h got=%h expected=%h resp=%h",a,s_axi_rdata,expected,s_axi_rresp);end s_axi_rready=1;@(negedge ctrl_clk);s_axi_rready=0;end endtask

reg [31:0] value,words[0:15];integer normals=0,faults=0,records=0;
task read_value(input [31:0] a,output [31:0] v);
 begin
  @(negedge ctrl_clk);s_axi_araddr=a;s_axi_arvalid=1;
  do @(posedge ctrl_clk);while(!s_axi_arready);
  @(negedge ctrl_clk);s_axi_arvalid=0;wait(s_axi_rvalid);v=s_axi_rdata;
  repeat(4)begin @(negedge ctrl_clk);if(!s_axi_rvalid||s_axi_rresp!=0||s_axi_rdata!==v)$fatal(1,"unstable read response");end
  s_axi_rready=1;@(negedge ctrl_clk);s_axi_rready=0;
 end
endtask
task normal(input integer id);
 begin
  @(negedge rf_clk);rf_event_data=0;rf_event_data[31:0]=32'h10001;
  rf_event_data[95:64]=id;rf_event_data[447:416]=32'hffffffff;rf_event_valid=1;
  do @(posedge rf_clk);while(!rf_event_ready);
  @(negedge rf_clk);rf_event_valid=0;
 end
endtask
task fault(input integer id);
 begin
  @(negedge rf_clk);rf_fault_snapshot=0;rf_fault_snapshot[31:0]=32'h30001;
  rf_fault_snapshot[63:32]=3;rf_fault_snapshot[95:64]=id;
  rf_fault_snapshot[255:192]=id*4;rf_fault_valid=1;
  @(negedge rf_clk);rf_fault_valid=0;
 end
endtask
initial begin
 #31;rst_n=1;repeat(5)@(negedge ctrl_clk);
 rd(REG_EVENT_COUNT,0,0);wr(REG_EVENT_LATCH,1,15,2);wr(REG_EVENT_POP,1,15,2);rd(REG_EVENT_WORD_0,0,2);
 for(integer n=1;n<=4;n++)normal(n);
 repeat(20)@(negedge ctrl_clk);rd(REG_EVENT_COUNT,2,0);
 for(integer n=1;n<=40;n++)fault(n);
 if(rf_event_dropped!=0)$fatal(1,"blocked queue counted as drop");
 while(normals<4||faults<40)begin
  read_value(REG_EVENT_COUNT,value);
  if(value!=0)begin
   wr(REG_EVENT_POP,1,15,2);
   wr(REG_EVENT_LATCH,1,0,2);wr(REG_EVENT_LATCH,2,15,2);
   // W before AW and stalled B; action must execute exactly once.
   wd(1,15);repeat(3)@(negedge ctrl_clk);aw(REG_EVENT_LATCH);br(0);
   for(integer w=15;w>=0;w--)read_value(REG_EVENT_WORD_0+w*4,words[w]);
   wr(REG_EVENT_LATCH,1,15,0);
   for(integer w=0;w<16;w++)rd(REG_EVENT_WORD_0+w*4,words[w],0);
   if(words[0]==32'h10001)begin
    normals++;if(words[2]!=normals||words[13]!=32'hffffffff)$fatal(1,"normal order/payload");
    for(integer w=1;w<16;w++)if(w!=2&&w!=13&&words[w]!=0)$fatal(1,"normal reserved");
   end else if(words[0]==32'h40001)begin
    if(words[1]!=0||words[2]==0||words[3]!=0||words[4]!=32'h30001||words[5]!=3||words[6]!=faults+1||words[10]!=(faults+1)*4)$fatal(1,"fault first snapshot/count");
    for(integer w=7;w<16;w++)if(w!=10&&words[w]!=0)$fatal(1,"fault reserved");
    faults+=words[2];
   end else $fatal(1,"tag");
   wr(REG_EVENT_POP,1,0,2);wr(REG_EVENT_POP,1,15,0);records++;
   wr(REG_EVENT_POP,1,15,2);rd(REG_EVENT_WORD_0,0,2);
  end
 end
 repeat(20)@(negedge ctrl_clk);rd(REG_EVENT_COUNT,0,0);
 if(rf_event_dropped!=0||faults!=40)$fatal(1,"loss/duplication");
 normal(99);fault(41);repeat(20)@(negedge ctrl_clk);wr(REG_EVENT_LATCH,1,15,0);
 @(negedge ctrl_clk);rst_n=0;#23;rst_n=1;repeat(20)@(negedge ctrl_clk);
 rd(REG_EVENT_COUNT,0,0);rd(REG_EVENT_WORD_0,0,2);wr(REG_EVENT_POP,1,15,2);
 normal(5);repeat(20)@(negedge ctrl_clk);wr(REG_EVENT_LATCH,1,15,0);rd(REG_EVENT_WORD_0+8,5,0);wr(REG_EVENT_POP,1,15,0);rd(REG_EVENT_COUNT,0,0);
 $display("PASS unified EVENT AXI: normals=%0d faults=%0d records=%0d stalled responses, invalid commands, reset",normals,faults,records);$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
