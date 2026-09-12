`timescale 1ns/1ps
module tb_capture_array;
reg clk=0,memclk=0;always #4 clk=~clk;always #2.5 memclk=~memclk;
reg [255:0] data=0;reg [15:0] we=0,fr=0,fm=0,ar=0,br=0;
reg [2:0] wa=0;reg [47:0] aa=0;reg [31:0] ba=0;
reg qa=0,qb=0;wire [1023:0] ad;wire [2047:0] bd;wire [15:0] av,bv;
capture_bank_array #(.ADDR_W(3)) dut(.clk_rf(clk),.clk_mem(memclk),.quiesce_rf(qa),.quiesce_mem(qb),.group_data(data),.write_enable(we),.write_address(wa),.frozen_rf(fr),.frozen_mem(fm),.replay_enable(ar),.replay_address(aa),.replay_data(ad),.replay_valid(av),.record_enable(br),.record_address(ba),.record_data(bd),.record_valid(bv));
integer i,j;
initial begin
 for(i=0;i<8;i=i+1) begin
 @(negedge clk);wa=i;we=16'hffff;
 for(j=0;j<4;j=j+1)data[j*64+:64]=j*100+i;
 @(posedge clk);#1;
 end
 @(negedge clk);we=0;fr=16'hffff;fm=16'hffff;ar=16'hffff;br=16'hffff;
 for(j=0;j<16;j=j+1) begin aa[j*3+:3]=3;ba[j*2+:2]=1;end
 @(posedge clk);#1;@(posedge memclk);#1;
 for(j=0;j<16;j=j+1) begin
 if(ad[j*64+:64]!=(j/4)*100+3 || bd[j*128+:64]!=(j/4)*100+2 || bd[j*128+64+:64]!=(j/4)*100+3) $fatal(1,"broadcast bank %0d data/read ports",j);
 end
 @(negedge clk);we=16'hffff;wa=3;data=0;
 @(posedge clk);#1;@(posedge clk);#1;
 if(ad[0+:64]!=3) $fatal(1,"frozen write protection");
 @(negedge clk);fr=0;fm=0;
 @(posedge clk);#1;@(posedge memclk);#1;
 if(av!=0 || bv!=0) $fatal(1,"mutable reads forbidden");
 @(negedge clk);fr=16'hffff;fm=16'hffff;qa=1;qb=1;
 @(posedge clk);#1;@(posedge memclk);#1;if(av!=0 || bv!=0) $fatal(1,"quiesce gates readers");
 $display("PASS capture array: 16 physical instances, four group broadcast, dual read, frozen write and mutable read protection, quiescence");$finish;
end
endmodule
