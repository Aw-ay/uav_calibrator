// PS-controlled bring-up stream. No RF/PA control and no reliance on ADC data.
module platform_counter_source(
 (* X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF m_axis, ASSOCIATED_RESET rst_n, FREQ_HZ 96968727" *) input wire clk,
 (* X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input wire rst_n,
 input wire [31:0] control,output wire [31:0] status,
 output reg [127:0] m_axis_tdata,output reg [15:0] m_axis_tkeep,
 output reg m_axis_tlast,output reg m_axis_tvalid,input wire m_axis_tready
);
 reg seen_start,done,error;reg [23:0] remaining;reg [7:0] offset;
 wire [23:0] length=control[31:8];
 assign status={24'd0,4'd0,control[1],error,done,m_axis_tvalid};
 task load_beat(input [23:0] bytes_left,input [7:0] first);
 begin
  for(integer b=0;b<16;b=b+1)begin
   m_axis_tdata[b*8+:8]<=b<bytes_left ? (first+b) : 0;
   m_axis_tkeep[b]<=b<bytes_left;
  end
  m_axis_tlast<=bytes_left<=16;
 end
 endtask
 always @(posedge clk)begin
  if(!rst_n)begin seen_start<=0;done<=0;error<=0;remaining<=0;offset<=0;m_axis_tvalid<=0;m_axis_tdata<=0;m_axis_tkeep<=0;m_axis_tlast<=0;end
  else begin
   seen_start<=control[0];
   if(m_axis_tvalid && m_axis_tready)begin
    if(remaining<=16)begin m_axis_tvalid<=0;done<=1;end
    else begin remaining<=remaining-16;offset<=offset+8'd16;load_beat(remaining-16,offset+8'd16);end
   end
   if(control[0]!=seen_start)begin
    if(m_axis_tvalid || control[1] || length==0 || length>262144 || control[7:2]!=0)error<=1;
    else begin done<=0;error<=0;remaining<=length;offset<=0;m_axis_tvalid<=1;load_beat(length,0);end
   end
  end
 end
endmodule
