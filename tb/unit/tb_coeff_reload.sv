`timescale 1ns/1ps
module tb_coeff_reload;
reg clk=0;always #4 clk=~clk;reg rst=1,ipreset=0,beginload=0,lv=0,commit=0,safe=0,confirmed=0,re=0,ce=0;
reg [31:0] version=1,rlen=2,clen=1,crc=0,word=0;reg [1:0] refs=0;
wire lr,loaded,busy,q,done,error,resetreq,av,ab;wire [31:0] aversion;wire rv,rlast,cv,clast;wire [23:0] rd;wire [7:0] cd;reg rr=0,cr=0;
coeff_reload_bridge #(.MAX_RELOAD_WORDS(4),.MAX_CONFIG_WORDS(2)) dut(.clk(clk),.rst(rst),.fir_reset_done(ipreset),.load_begin(beginload),.load_version(version),.load_reload_count(rlen),.load_config_count(clen),.load_crc32c(crc),.load_valid(lv),.load_data(word),.load_ready(lr),.loaded(loaded),.bank_ref_busy(refs),.commit(commit),.safe_boundary(safe),.apply_confirmed(confirmed),.ip_reload_error(re),.ip_config_error(ce),.busy(busy),.quiesce_request(q),.commit_done(done),.error(error),.reset_required(resetreq),.active_valid(av),.active_version(aversion),.active_bank_id(ab),.m_axis_reload_tvalid(rv),.m_axis_reload_tready(rr),.m_axis_reload_tdata(rd),.m_axis_reload_tlast(rlast),.m_axis_config_tvalid(cv),.m_axis_config_tready(cr),.m_axis_config_tdata(cd),.m_axis_config_tlast(clast));
function [31:0] cw(input [31:0] c,input [31:0] w);reg [31:0] x;integer k;begin x=c;for(k=0;k<32;k=k+1)if(x[0]^w[k])x=(x>>1)^32'h82f63b78;else x=x>>1;cw=x;end endfunction
task tick;begin @(posedge clk);#1;end endtask
task load(input [31:0] ver,input bad);begin
 @(negedge clk);version=ver;crc=bad?0:~cw(cw(cw(32'hffffffff,32'h123456),32'hffffff),32'h3);beginload=1;tick;
 @(negedge clk);beginload=0;version=99;lv=1;word=32'h123456;tick;
 @(negedge clk);word=32'hffffff;tick;@(negedge clk);word=3;tick;@(negedge clk);lv=0;
end endtask
initial begin
 tick;rst=0;@(negedge clk);beginload=1;tick;if(!error||lr)$fatal(1,"unknown IP state accepted");
 @(negedge clk);beginload=0;ipreset=1;tick;@(negedge clk);ipreset=0;
 load(1,1);if(!error||loaded||av)$fatal(1,"CRC accepted");
 load(1,0);if(!loaded||av)$fatal(1,"load/active confusion");
 commit=1;tick;@(negedge clk);commit=0;safe=1;refs=1;tick;if(rv||!q)$fatal(1,"overwrote pinned coefficients");
 @(negedge clk);refs=0;tick;if(!rv||rd!=24'h123456||rlast)$fatal(1,"reload first");
 repeat(3)begin tick;if(!rv||rd!=24'h123456||rlast||cv)$fatal(1,"reload stall unstable");end
 @(negedge clk);rr=1;tick;if(!rv||rd!=24'hffffff||!rlast)$fatal(1,"reload last");
 @(negedge clk);rr=0;tick;if(!rlast||rd!=24'hffffff)$fatal(1,"last stall");
 @(negedge clk);rr=1;tick;if(!cv||cd!=3||!clast||rv)$fatal(1,"config packet");
 repeat(3)begin tick;if(!cv||cd!=3||!clast||av||done)$fatal(1,"config stall");end
 @(negedge clk);cr=1;tick;if(av||done||cv)$fatal(1,"config acceptance falsely applied");
 @(negedge clk);confirmed=1;tick;if(!done||!av||aversion!=1||ab!=1)$fatal(1,"apply version snapshot");
 @(negedge clk);confirmed=0;
 load(2,0);commit=1;tick;@(negedge clk);commit=0;tick;
 @(negedge clk);re=1;rr=0;tick;if(!resetreq||av||!rv)$fatal(1,"error must preserve stalled transfer");
 @(negedge clk);re=0;rr=1;tick;tick;if(cv||done||av||!resetreq)$fatal(1,"bad reload configured");
 @(negedge clk);ipreset=1;tick;@(negedge clk);ipreset=0;commit=1;tick;if(!error||av||rv||cv||resetreq)$fatal(1,"reset reused table");
 // Two-beat CONFIG packet and error coincident with final acceptance.
 @(negedge clk);commit=0;clen=2;version=3;crc=~cw(cw(cw(cw(32'hffffffff,32'h123456),32'hffffff),32'h3),32'h4);beginload=1;tick;
 @(negedge clk);beginload=0;lv=1;word=32'h123456;tick;@(negedge clk);word=32'hffffff;tick;
 @(negedge clk);word=3;tick;@(negedge clk);word=4;tick;@(negedge clk);lv=0;commit=1;tick;
 @(negedge clk);commit=0;cr=0;tick;tick;tick;if(!cv||cd!=3||clast)$fatal(1,"multi config first");
 @(negedge clk);cr=1;tick;if(!cv||cd!=4||!clast)$fatal(1,"multi config last");
 @(negedge clk);ce=1;confirmed=1;tick;if(av||done||!resetreq)$fatal(1,"config error raced apply");
 @(negedge clk);ce=0;confirmed=0;rst=1;tick;if(av||cv||rv)$fatal(1,"reset validity");
 @(negedge clk);rst=0;ipreset=1;tick;@(negedge clk);ipreset=0;version=4;beginload=1;tick;
 @(negedge clk);beginload=0;refs=2;lv=1;word=0;tick;if(!error||lr||loaded)$fatal(1,"inactive reference write protection");
 @(negedge clk);refs=0;word=32'h123456;tick;@(negedge clk);word=32'hffffff;tick;
 @(negedge clk);word=3;tick;@(negedge clk);word=4;tick;if(!loaded)$fatal(1,"pinned write corrupted candidate");
 $display("PASS coefficient CRC pin reload config apply error reset");$finish;
end
endmodule
