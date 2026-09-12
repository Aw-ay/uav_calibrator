`timescale 1ns/1ps
module tb_awg_reader;
reg clk=0;always #4 clk=~clk; reg rst=1,load_begin=0,load_valid=0,commit=0,boundary=0,play=0;
reg [31:0] length=2,crc=0;reg [63:0] word=0;
wire ready,loaded,ca,err,active,playing,valid,last;wire [63:0] data;
awg_reader #(.DEPTH(4)) dut(.clk(clk),.rst(rst),.load_begin(load_begin),.load_length(length),.load_crc32c(crc),.load_valid(load_valid),.load_data(word),.load_ready(ready),.loaded(loaded),.commit(commit),.safe_boundary(boundary),.commit_ack(ca),.error(err),.active_valid(active),.play(play),.playing(playing),.out_valid(valid),.out_last(last),.out_data(data));
function [31:0] crcword(input [31:0] c,input [63:0] w);
reg [31:0] x;integer i;begin x=c;for(i=0;i<64;i=i+1)begin if(x[0]^w[i])x=(x>>1)^32'h82f63b78;else x=x>>1;end crcword=x;end endfunction
task tick;begin @(posedge clk);#1;end endtask
task load(input [31:0] expected);begin
 @(negedge clk);load_begin=1;crc=expected;tick;@(negedge clk);load_begin=0;load_valid=1;word=64'h0123456789abcdef;tick;@(negedge clk);word=64'hfedcba9876543210;tick;@(negedge clk);load_valid=0;
end endtask
initial begin
 tick;rst=0;
 load(0);if(!err||loaded||active)$fatal(1,"bad CRC accepted");
 load(~crcword(crcword(32'hffffffff,64'h0123456789abcdef),64'hfedcba9876543210));if(!loaded||active)$fatal(1,"load visibility");
 commit=1;tick;@(negedge clk);commit=0;tick;if(active)$fatal(1,"unsafe commit");
 @(negedge clk);boundary=1;tick;if(!ca||!active)$fatal(1,"atomic commit");
 @(negedge clk);play=1;tick;@(negedge clk);play=0;tick;if(!valid||data!=64'h0123456789abcdef||last)$fatal(1,"first word");
 tick;if(!valid||data!=64'hfedcba9876543210||!last)$fatal(1,"last word");
 tick;if(valid||data!=0)$fatal(1,"idle zero");
 // A complete replacement cannot change the bank pinned by a concurrent play.
 @(negedge clk);load_begin=1;crc=~crcword(crcword(32'hffffffff,64'd55),64'd66);tick;
 @(negedge clk);load_begin=0;load_valid=1;word=55;tick;
 @(negedge clk);word=66;tick;
 @(negedge clk);load_valid=0;commit=1;play=1;tick;
 @(negedge clk);commit=0;play=0;tick;if(ca||data!=64'h0123456789abcdef)$fatal(1,"active bank modified");
 tick;if(ca||data!=64'hfedcba9876543210||!last)$fatal(1,"bank pin lost");
 tick;if(!ca)$fatal(1,"deferred commit lost");
 @(negedge clk);play=1;tick;@(negedge clk);play=0;tick;if(data!=55||!valid)$fatal(1,"new table first");
 tick;if(data!=66||!last)$fatal(1,"new table last");
 @(negedge clk);load_begin=1;length=5;tick;if(!err||ready)$fatal(1,"oversized table");
 $display("PASS AWG CRC atomic commit playback");$finish;
end
endmodule
