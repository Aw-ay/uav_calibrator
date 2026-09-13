`timescale 1ns/1ps
module tb_control;
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
wire rf_fault_valid=1'b0;wire [255:0] rf_fault_snapshot=256'b0;
csr_control_axi dut(.*);
task aw(input [31:0] a); begin @(negedge ctrl_clk);s_axi_awaddr=a;s_axi_awvalid=1; do @(posedge ctrl_clk);while(!s_axi_awready);@(negedge ctrl_clk);s_axi_awvalid=0;end endtask
task wd(input [31:0] d,input [3:0] st);begin @(negedge ctrl_clk);s_axi_wdata=d;s_axi_wstrb=st;s_axi_wvalid=1;do @(posedge ctrl_clk);while(!s_axi_wready);@(negedge ctrl_clk);s_axi_wvalid=0;end endtask
task br(input [1:0] expected);begin wait(s_axi_bvalid);repeat(3)begin @(negedge ctrl_clk);if(!s_axi_bvalid || s_axi_bresp!==expected)$fatal(1,"B response");end s_axi_bready=1;@(negedge ctrl_clk);s_axi_bready=0;end endtask
task wr(input [31:0] a,d,input [3:0] st,input [1:0] e);begin aw(a);repeat(2)@(negedge ctrl_clk);wd(d,st);br(e);end endtask
task rd(input [31:0] a,expected,input [1:0] resp);begin @(negedge ctrl_clk);s_axi_araddr=a;s_axi_arvalid=1;do @(posedge ctrl_clk);while(!s_axi_arready);@(negedge ctrl_clk);s_axi_arvalid=0;wait(s_axi_rvalid);repeat(3)begin @(negedge ctrl_clk);if(s_axi_rdata!==expected || s_axi_rresp!==resp || !s_axi_rvalid)$fatal(1,"R a=%h got=%h expected=%h resp=%h",a,s_axi_rdata,expected,s_axi_rresp);end s_axi_rready=1;@(negedge ctrl_clk);s_axi_rready=0;end endtask
reg [63:0] saved;
initial begin
#31;rst_n=1;repeat(5)@(negedge ctrl_clk);
rd(4,5,0);rd(12,0,0);if(armed||tx_enable)$fatal;
wr(0,0,15,2);rd('hdead,0,2);wr('h304,1,15,2);
wd('h12345678,15);repeat(4)@(negedge ctrl_clk);aw('h104);br(0);rd('h104,'h12345678,0);
wr('h104,'haabbccdd,5,0);rd('h104,'h12bb56dd,0);
wr('h100,1,15,0);wr('h108,1,15,0);
wr('h104,99,15,0);wr('h108,1,15,2);rd('h10c,0,0);
@(negedge rf_clk);rf_safe_boundary=1;@(negedge rf_clk);rf_safe_boundary=0;
repeat(10)@(negedge ctrl_clk);rd('h10c,'h12bb56dd,0);
if(active_config_id!==32'h12bb56dd || active_mode!==1)$fatal(1,"atomic config");
wr('h10,1,15,2);if(armed)$fatal;
@(negedge rf_clk);rf_run=0;wr('h10,4,15,0);wr('h10,4,15,2);rf_run=1;repeat(15)@(negedge ctrl_clk);saved=dut.snapshot_value;
if(saved==0 || saved[1:0]!=0 || saved>gsc)$fatal(1,"snapshot");
rd('h210,6,0);rd('h200,saved[31:0],0);repeat(10)@(negedge ctrl_clk);rd('h204,saved[63:32],0);
@(negedge ctrl_clk);fault_set=32'h1234;@(negedge ctrl_clk);fault_set=0;rd('h18,'h1234,0);
wr('h18,'hffff,1,0);rd('h18,'h1200,0);
@(negedge ctrl_clk);fault_set='h1200;wr('h18,'hffff,15,0);fault_set=0;rd('h18,'h1200,0);
wr('h18,'hffff,15,0);rd('h18,0,0);
@(negedge rf_clk);dut.timebase.gsc=64'h00000001fffffff0;
wr('h10,4,15,0);repeat(15)@(negedge ctrl_clk);saved=dut.snapshot_value;
if(saved[63:32]!=2)$fatal(1,"rollover snapshot");rd('h210,10,0);rd('h200,saved[31:0],0);rd('h204,saved[63:32],0);
wr('h810,32,15,0);wr('h108,1,15,0);rf_safe_boundary=1;repeat(15)@(negedge ctrl_clk);rf_safe_boundary=0;
calibration_valid=1;wr('h10,1,15,0);if(!armed)$fatal(1,"ARM");wr('h10,2,15,0);if(armed)$fatal;
rd('h300,0,0);wr('h308,1,15,2);
@(negedge rf_clk);while(!rf_event_ready)@(negedge rf_clk);
for(integer w=0;w<16;w=w+1)rf_event_data[w*32+:32]=32'h12340000+w;
rf_event_valid=1;@(negedge rf_clk);rf_event_valid=0;
repeat(12)@(negedge ctrl_clk);rd('h300,1,0);wr('h304,1,15,0);
for(integer w=15;w>=0;w=w-1)rd('h340+w*4,32'h12340000+w,0);
rd('h300,1,0);wr('h308,1,15,0);rd('h300,0,0);rd('h340,0,2);
wr('h108,1,15,0);rst_n=0;#19;rst_n=1;repeat(15)@(negedge ctrl_clk);rd('h10c,0,0);rd('h110,0,0);
if(armed||tx_enable)$fatal; $display("PASS control AXI CDC snapshot faults reset");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
