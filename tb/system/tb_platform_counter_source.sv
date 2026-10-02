`timescale 1ns/1ps
module tb_platform_counter_source;
reg clk=0;always #5 clk=~clk;reg rst_n=0;reg [31:0] control=0;wire [31:0] status;
wire [127:0] m_axis_tdata;wire [15:0] m_axis_tkeep;wire m_axis_tlast,m_axis_tvalid;reg m_axis_tready=0;
platform_counter_source dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
integer received=0;reg [144:0] held;
task packet(input integer n);begin
 control=(n<<8)|((control^1)&1);tick();
 while(m_axis_tvalid)begin
  if(n==257 && received==0)control=control|2;
  held={m_axis_tdata,m_axis_tkeep,m_axis_tlast};repeat(3)begin tick();if({m_axis_tdata,m_axis_tkeep,m_axis_tlast}!==held)$fatal(1,"stall");end
  for(integer b=0;b<16;b=b+1)begin
   if(m_axis_tkeep[b])begin if(m_axis_tdata[b*8+:8]!==((received+b)&255))$fatal(1,"counter data");end
   if(m_axis_tkeep[b]!==((received+b)<n))$fatal(1,"keep");
  end
  if(m_axis_tlast!==((received+16)>=n))$fatal(1,"last");
  m_axis_tready=1;tick();m_axis_tready=0;received=received+16;
 end
 if(!status[1]||status[0])$fatal(1,"completion");received=0;
end endtask
initial begin tick();rst_n=1;packet(1);packet(17);packet(257);packet(131216);packet(262144);
 control=control|2;tick();control=(32'd31<<8)|2|((control^1)&1);tick();if(m_axis_tvalid||!status[3])$fatal(1,"stop");
 control=control&~2;tick();packet(32);
 control=((control^1)&1);tick();if(m_axis_tvalid||!status[2])$fatal(1,"zero length");
 $display("PASS PLATFORM_COUNTER bytes/actual length/TKEEP/TLAST, stalls, stop and invalid request");$finish;end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
