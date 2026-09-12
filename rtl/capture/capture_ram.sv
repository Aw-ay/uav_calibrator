// One independent mixed-width true dual-port storage instance per physical bank.
// A: sample address; B: natural pair address, {odd sample, even sample}.
module capture_ram #(parameter integer ADDR_W=14)(
 input wire clka,ena,wea,input wire [ADDR_W-1:0] addra,input wire [63:0] dina,output wire [63:0] douta,
 input wire clkb,enb,input wire [ADDR_W-2:0] addrb,output wire [127:0] doutb);
`ifdef SYNTHESIS
 capture_ram_probe ram_ip(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta),
 .clkb(clkb),.enb(enb),.web(1'b0),.addrb(addrb),.dinb(128'b0),.doutb(doutb));
`else
 reg [63:0] even_mem[0:(1<<(ADDR_W-1))-1];
 reg [63:0] odd_mem[0:(1<<(ADDR_W-1))-1];
 reg [63:0] a_q; reg [127:0] b_q;
 assign douta=a_q;assign doutb=b_q;
 always @(posedge clka) if(ena) begin
   if(addra[0]) begin a_q<=odd_mem[addra[ADDR_W-1:1]];if(wea) odd_mem[addra[ADDR_W-1:1]]<=dina;end
   else begin a_q<=even_mem[addra[ADDR_W-1:1]];if(wea) even_mem[addra[ADDR_W-1:1]]<=dina;end
 end
 always @(posedge clkb) if(enb) b_q<={odd_mem[addrb],even_mem[addrb]};
`endif
endmodule
