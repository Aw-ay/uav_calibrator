`timescale 1ns/1ps
module tb_awg_load_cdc #(parameter integer CTRL_HALF=5, RF_HALF=4);
reg cc=0,rc=0;always #(CTRL_HALF) cc=~cc;always #(RF_HALF) rc=~rc;
reg rn=0,cv=0;reg [1:0] op=0;reg [31:0] len=2,crc=0;reg [63:0] word=0;wire ready,done,err;wire [1:0] dop;wire loaded,ca;
reg bound=0,play=0;wire active,playing,ov,last;wire [63:0] data;
awg_load_cdc_wrapper #(.DEPTH(4)) dut(.clk_ctrl(cc),.clk_rf(rc),.rst_n(rn),.ctrl_valid(cv),.ctrl_op(op),.ctrl_length(len),.ctrl_crc32c(crc),.ctrl_data(word),.ctrl_ready(ready),.ctrl_done(done),.ctrl_error(err),.ctrl_done_op(dop),.ctrl_loaded(loaded),.ctrl_active_valid(ca),.safe_boundary(bound),.play(play),.active_valid(active),.playing(playing),.out_valid(ov),.out_last(last),.out_data(data));
function [31:0] cw(input [31:0] c,input [63:0] w);reg [31:0] x;integer k;begin x=c;for(k=0;k<64;k=k+1)if(x[0]^w[k])x=(x>>1)^32'h82f63b78;else x=x>>1;cw=x;end endfunction
task send(input [1:0] o,input [63:0] d,input expected_error);
integer t;begin
 @(negedge cc);while(!ready)@(negedge cc);op=o;word=d;cv=1;
 @(posedge cc);#1;@(negedge cc);cv=0;word=64'hdeadbeef;op=3;
 t=0;while(!done&&t<200)begin @(posedge cc);#1;t=t+1;end
 if(!done||err!=expected_error||dop!=o)$fatal(1,"CDC response timeout/status op%0d",o);
end endtask
initial begin
 repeat(3)@(posedge cc);rn=1;
 crc=~cw(cw(32'hffffffff,64'h0123456789abcdef),64'hfedcba9876543210);
 send(0,0,0);send(1,64'h0123456789abcdef,0);send(1,64'hfedcba9876543210,0);
 if(!loaded||active)$fatal(1,"load status/visibility");
 fork
  send(2,0,0);
  begin repeat(20)@(posedge cc);if(done||active)$fatal(1,"commit acknowledged early");@(negedge rc);bound=1;end
 join
 if(!active||!ca||loaded)$fatal(1,"commit status");
 @(negedge rc);play=1;@(posedge rc);#1;@(negedge rc);play=0;@(posedge rc);#1;
 if(!ov||data!=64'h0123456789abcdef)$fatal(1,"CDC data tear first");
 @(posedge rc);#1;if(!ov||data!=64'hfedcba9876543210||!last)$fatal(1,"CDC data tear last");
 send(3,0,1);send(1,0,1);
 crc=0;send(0,0,0);send(1,5,0);send(1,6,1);send(2,0,1);
 // Coordinated reset cancels an in-flight command and clears active validity.
 @(negedge cc);while(!ready)@(negedge cc);cv=1;op=0;@(posedge cc);#1;rn=0;cv=0;
 #1;if(data!=0||ov)$fatal(1,"reset output safety");
 repeat(3)@(posedge cc);rn=1;repeat(20)begin @(posedge cc);#1;if(done)$fatal(1,"ghost response after reset");end
 if(active||!ready)$fatal(1,"reset recovery");
 $display("PASS AWG asynchronous load CRC commit reset");$finish;
end
endmodule
