// Sixteen physically independent mixed-width memories. Mutable samples broadcast
// to all banks of their role; frozen consumers independently use A and B.
// frozen_mem must be a clk_mem-domain ownership lease from a handshake/CDC bridge;
// DO NOT wire asynchronous frozen_rf directly. Quiescence is domain-local too.
module capture_bank_array #(parameter integer ADDR_W=14)(
 input wire clk_rf,clk_mem,quiesce_rf,quiesce_mem,
 input wire [255:0] group_data,input wire [15:0] write_enable,input wire [ADDR_W-1:0] write_address,
 input wire [15:0] frozen_rf,frozen_mem,
 input wire [15:0] replay_enable,input wire [16*ADDR_W-1:0] replay_address,
 output wire [1023:0] replay_data,output reg [15:0] replay_valid,
 input wire [15:0] record_enable,input wire [16*(ADDR_W-1)-1:0] record_address,
 output wire [2047:0] record_data,output reg [15:0] record_valid
);
 wire [15:0] wr,ra,rb;
 assign wr=write_enable & ~frozen_rf & {16{!quiesce_rf}};
 assign ra=replay_enable & frozen_rf & {16{!quiesce_rf}};
 assign rb=record_enable & frozen_mem & {16{!quiesce_mem}};
 always @(posedge clk_rf) replay_valid<=ra;
 always @(posedge clk_mem) record_valid<=rb;
 genvar b;generate for(b=0;b<16;b=b+1) begin: banks
 capture_ram #(.ADDR_W(ADDR_W)) ram(
 .clka(clk_rf),.ena(wr[b]|ra[b]),.wea(wr[b]),
 .addra(wr[b]?write_address:replay_address[b*ADDR_W+:ADDR_W]),
 .dina(group_data[(b/4)*64+:64]),.douta(replay_data[b*64+:64]),
 .clkb(clk_mem),.enb(rb[b]),.addrb(record_address[b*(ADDR_W-1)+:(ADDR_W-1)]),.doutb(record_data[b*128+:128]));
 end endgenerate
endmodule
