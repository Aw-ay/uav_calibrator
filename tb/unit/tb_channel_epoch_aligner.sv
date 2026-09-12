`timescale 1ns/1ps
module tb_channel_epoch_aligner;
reg clk=0;always #4 clk=~clk;reg rst=1,beat=0,cgood=1,mgood=1;
reg [63:0] seq=0,gsc=0;reg [511:0] cseq=0,cgsc=0,ii=0,qq=0;reg [7:0] valid=255,lock=255;reg [1:0] sw=0,settle=0;
wire ov,pv,fault;wire [7:0] mask,bad;wire [31:0] epoch;wire [63:0] ae,os,og;wire [511:0] oi,oq;
channel_epoch_aligner dut(.clk(clk),.rst(rst),.in_valid(beat),.expected_seq(seq),.gsc_base(gsc),.channel_seq(cseq),.channel_gsc(cgsc),.iq_i(ii),.iq_q(qq),.channel_valid(valid),.channel_mts_locked(lock),.common_clock_good(cgood),.common_mts_good(mgood),.aux_switch_event(sw),.aux_settling(settle),.out_valid(ov),.out_seq(os),.out_gsc(og),.out_i(oi),.out_q(oq),.valid_mask(mask),.primary_valid(pv),.mismatch_mask(bad),.common_fault(fault),.clock_epoch(epoch),.aux_source_epoch(ae));
task tick;begin @(posedge clk);#1;end endtask
integer i;
task setseq(input [63:0] s);begin seq=s;gsc=s;for(i=0;i<8;i=i+1)begin cseq[i*64+:64]=s;cgsc[i*64+:64]=s;end end endtask
initial begin
 tick;rst=0;@(negedge clk);beat=1;ii=512'h12345;qq=512'h76543;tick;if(mask!=255||!pv||oi!=ii||oq!=qq)$fatal(1,"healthy stream");
 @(negedge clk);setseq(4);sw=1;settle=1;valid=8'h77;tick;if(mask!=8'h77||!pv||os!=4||ae[31:0]!=1)$fatal(1,"AUX stalls main");
 @(negedge clk);setseq(8);sw=0;tick;if(!pv||os!=8||ae[31:0]!=1)$fatal(1,"main continuity");
 @(negedge clk);valid=255;settle=0;cseq[2*64+:64]=9;tick;if(mask!=8'hfb||pv||bad!=4)$fatal(1,"sequence mismatch");
 @(negedge clk);setseq(12);cgood=0;tick;if(mask||!fault||epoch!=1)$fatal(1,"clock fault");
 tick;if(epoch!=1)$fatal(1,"epoch increments repeatedly");
 @(negedge clk);cgood=1;tick;if(mask!=255||epoch!=1)$fatal(1,"clock recovery");
 @(negedge clk);mgood=0;tick;if(mask||epoch!=2)$fatal(1,"MTS fault");
 @(negedge clk);mgood=1;lock=8'h7f;tick;if(mask!=8'h7f||!pv)$fatal(1,"AUX MTS stalls main");
 @(negedge clk);lock=255;cgsc[7*64+:64]=13;tick;if(mask!=8'h7f||!pv||bad!=128)$fatal(1,"timestamp mismatch");
 @(negedge clk);beat=0;cgood=0;tick;if(ov||mask||epoch!=3)$fatal(1,"idle common fault");
 $display("PASS channel epoch isolation");$finish;
end
endmodule
