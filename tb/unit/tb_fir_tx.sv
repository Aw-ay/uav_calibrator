module tb_fir_tx;
reg clk=0; always #4 clk=~clk;
reg rst=1,in_valid=0; reg [15:0] in_i=0,in_q=0;
wire out_valid; wire [63:0] out_i,out_q; wire [1:0] out_sat;
fir_tx_lane dut(.*);
integer fd,rc,cycle=0; reg [13:0] valid_ref=0;
initial begin
 fd=$fopen("tb/vectors/fir_tx.txt","r");
 while (!$feof(fd)) begin
 @(negedge clk); rc=$fscanf(fd,"%d %d %h %h\n",rst,in_valid,in_i,in_q);
 @(posedge clk);
 if(rst) valid_ref=0; else valid_ref={valid_ref[12:0],in_valid};
 #1; if(out_valid!==valid_ref[13]) $fatal(1,"latency cycle %0d",cycle);
 if(out_valid) $display("DATA %h %h %h",out_i,out_q,out_sat);
 cycle=cycle+1;
 end
 $finish; end
endmodule
