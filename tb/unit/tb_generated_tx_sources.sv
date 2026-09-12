`timescale 1ns/1ps
module tb_generated_tx_sources;
reg cc=0,rc=0;always #5 cc=~cc;always #4 rc=~rc;
reg rn=0,stop=0,safe=1;reg [63:0] gsc=0;always @(posedge rc)if(rn)gsc<=gsc+4;else gsc<=0;
reg dc=0;reg [63:0] start=0;reg [31:0] pw=4,pri=6,count=2;
wire da,dr,db,dd,dv;wire [63:0] ddata,dgsc;
reg cv=0;reg [1:0] op=0;reg [31:0] len=0,crc=0;reg [63:0] word=0;
wire cr,cd,ce,cl,ca;wire [1:0] cop;
reg play=0;wire pa,pr,ab,av,al,ad,acancel,drained;wire [63:0] adata,agsc;
generated_tx_sources #(.AWG_DEPTH(256)) dut(.clk_ctrl(cc),.clk_rf(rc),.rst_n(rn),.gsc(gsc),.stop_request(stop),.safe_boundary(safe),
 .dds_cmd_valid(dc),.dds_start_gsc(start),.dds_pw_samples(pw),.dds_pri_samples(pri),.dds_pulse_count(count),.dds_initial_pinc(48'h400000000000),.dds_chirp_step(48'h400000000000),.dds_reset_each_pulse(1'b1),.dds_accepted(da),.dds_rejected(dr),.dds_busy(db),.dds_done(dd),.dds_data(ddata),.dds_valid(dv),.dds_sample_gsc(dgsc),
 .awg_ctrl_valid(cv),.awg_ctrl_op(op),.awg_ctrl_length(len),.awg_ctrl_crc32c(crc),.awg_ctrl_data(word),.awg_ctrl_ready(cr),.awg_ctrl_done(cd),.awg_ctrl_error(ce),.awg_ctrl_done_op(cop),.awg_ctrl_loaded(cl),.awg_ctrl_active_valid(ca),.awg_play(play),.awg_play_accepted(pa),.awg_play_rejected(pr),.awg_busy(ab),.awg_done(ad),.awg_done_cancelled(acancel),.awg_data(adata),.awg_valid(av),.awg_last(al),.awg_sample_gsc(agsc),.sources_drained(drained));
function [31:0] cw(input [31:0] c,input [63:0] w);reg [31:0] x;integer k;begin x=c;for(k=0;k<64;k=k+1)if(x[0]^w[k])x=(x>>1)^32'h82f63b78;else x=x>>1;cw=x;end endfunction
function [63:0] oldword(input integer n);begin oldword=64'h0004000300020001+n;end endfunction
function [63:0] ddsword(input integer n);reg [31:0] z;begin case(n%4)0:z=32'h00007fff;1:z=32'h7fff0000;2:z=32'h80010000;3:z=32'h00008001;endcase ddsword={z,z};end endfunction
task rtick;begin @(posedge rc);#1;end endtask
task send(input [1:0] o,input [63:0] w);integer timeout;begin
 @(negedge cc);while(!cr)@(negedge cc);op=o;word=w;cv=1;@(posedge cc);#1;@(negedge cc);cv=0;word=64'hdeadbeef;
 timeout=0;while(!cd&&timeout<1000)begin @(posedge cc);#1;timeout=timeout+1;end
 if(!cd||ce||cop!=o)$fatal(1,"AWG transaction %0d",o);
end endtask
integer dn=0,an=0,i,t,awg_done_count=0;reg cancelled_done_seen=0;reg checkdds=0,checkawg=0;reg [31:0] accum;reg [63:0] firstawg;
always @(posedge rc)begin #1;
 if(ad)begin awg_done_count=awg_done_count+1;if(acancel)cancelled_done_seen=1;end
 if(checkdds&&dv)begin
  if(ddata!==ddsword(dn)||dgsc!=start+(dn/4)*24+(dn%4)*4)$fatal(1,"DDS data/time mismatch %0d",dn);
  dn=dn+1;
 end
 if(checkawg&&av)begin
  if(adata!==oldword(an)||agsc!=firstawg+an*4||al!=(an==255))$fatal(1,"active AWG disturbed %0d",an);
  an=an+1;
 end
end
initial begin
 repeat(3)rtick;rn=1;repeat(5)rtick;
 @(negedge rc);start=gsc+16;dc=1;checkdds=1;rtick;if(!da)$fatal(1,"DDS admit");@(negedge rc);dc=0;
 repeat(20)rtick;if(dn!=8||dv||ddata||!drained)$fatal(1,"DDS end/drain %0d",dn);checkdds=0;
 // Stop an actual in-flight DDS train, then reject restart until it is drained.
 @(negedge rc);start=gsc+12;pw=16;pri=16;count=2;dc=1;rtick;if(!da)$fatal(1,"DDS stop test admission");
 @(negedge rc);dc=0;t=0;while(!dv&&t<10)begin rtick;t=t+1;end
 if(!dv||ddata!=ddsword(0))$fatal(1,"DDS stop test waveform");
 @(negedge rc);stop=1;#1;if(dv||ddata)$fatal(1,"DDS stop zero");rtick;
 @(negedge rc);stop=0;dc=1;start=gsc+12;rtick;if(!dr)$fatal(1,"DDS restart during stop drain");
 @(negedge rc);dc=0;repeat(6)begin rtick;if(dv||ddata)$fatal(1,"DDS cancelled pulse returned");end
 if(!drained||db)$fatal(1,"DDS stop drain");
 len=256;accum=32'hffffffff;for(i=0;i<256;i=i+1)accum=cw(accum,oldword(i));crc=~accum;
 send(0,0);for(i=0;i<256;i=i+1)send(1,oldword(i));send(2,0);
 @(negedge rc);play=1;checkawg=1;firstawg=gsc+4;rtick;if(!pa)$fatal(1,"AWG play");@(negedge rc);play=0;
 // The other clock loads a different inactive table while this 256-word table plays.
 len=16;accum=32'hffffffff;for(i=0;i<16;i=i+1)accum=cw(accum,64'd55+i);crc=~accum;
 send(0,0);for(i=0;i<16;i=i+1)send(1,64'd55+i);if(!ab)$fatal(1,"test must commit during active playback");send(2,0);
 if(an!=256)$fatal(1,"old AWG length %0d",an);checkawg=0;
 @(negedge rc);play=1;rtick;@(negedge rc);play=0;rtick;if(!av||adata!=55)$fatal(1,"new table first");rtick;if(!av||adata!=56)$fatal(1,"new table second");
 @(negedge rc);stop=1;#1;if(ddata||adata||dv||av)$fatal(1,"stop immediate zero");rtick;if(drained)$fatal(1,"AWG bank released before final read");
 @(negedge rc);stop=0;play=1;rtick;if(!pr||av)$fatal(1,"cancelled tail restarted");@(negedge rc);play=0;
 t=0;while(!drained&&t<30)begin rtick;if(av||adata)$fatal(1,"cancelled tail visible");t=t+1;end
 if(!drained)$fatal(1,"AWG drain timeout");
 repeat(3)rtick;if(awg_done_count!=2||!cancelled_done_seen)$fatal(1,"cancelled drain completion status");@(negedge rc);play=1;rtick;if(!pa)$fatal(1,"post drain restart");@(negedge rc);play=0;rtick;if(adata!=55||!av)$fatal(1,"restart must begin table");
 @(negedge rc);rn=0;#1;if(adata||ddata||av||dv)$fatal(1,"reset zero");
 $display("PASS generated DDS chirp GSC AWG async bank stop drain");$finish;
end
endmodule
