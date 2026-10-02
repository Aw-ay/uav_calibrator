// Vivado BD module-reference shell; functional implementation is SystemVerilog.
module platform_counter_bd(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF m_axis, ASSOCIATED_RESET rst_n, FREQ_HZ 96968727" *) input clk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 rst_n RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input rst_n,
 input [31:0] control,output [31:0] status,
 output [127:0] m_axis_tdata,output [15:0] m_axis_tkeep,output m_axis_tlast,m_axis_tvalid,input m_axis_tready
);
platform_counter_source impl(.clk(clk),.rst_n(rst_n),.control(control),.status(status),.m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),.m_axis_tvalid(m_axis_tvalid),.m_axis_tready(m_axis_tready));
endmodule
