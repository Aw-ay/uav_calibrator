`timescale 1ns/1ps
module tb_waveform_sources;
reg clk=0; always #4 clk=~clk;
reg rst=1; reg [63:0] gsc=0;
always @(posedge clk) if(!rst) gsc<=gsc+4;
reg cmd=0; wire busy,accept,reject,en,gate,pr,done; wire [47:0] pinc;
reg [63:0] start=16; reg [31:0] pw=2,pri=4,count=2;
dds_burst_control b(.clk(clk),.rst(rst),.gsc(gsc),.cmd_valid(cmd),.start_gsc(start),.pw_samples(pw),.pri_samples(pri),.pulse_count(count),.initial_pinc(48'h400000000000),.chirp_step(48'd1),.reset_each_pulse(1'b1),.abort(1'b0),.busy(busy),.accepted(accept),.rejected(reject),.nco_enable(en),.envelope(gate),.phase_reset(pr),.pinc(pinc),.done(done));
wire ov; wire signed [15:0] ci,sq;
reg ne=0,nr=0,ng=1; reg [47:0] np=48'h400000000000;
dds_nco_wrapper n(.clk(clk),.rst(rst),.enable(ne),.phase_reset(nr),.pinc(np),.envelope(ng),.out_valid(ov),.cos_out(ci),.sin_out(sq));
reg req=0,boundary=0,safe=1,ota=0; reg [2:0] mode=0; wire [2:0] active; wire [63:0] data; wire mv,ma,mr;
tx_source_mux m(.clk(clk),.rst(rst),.request(req),.requested_mode(mode),.safe_boundary(boundary),.rf_permit(safe),.single_antenna_ota(ota),.live_data(64'd11),.live_valid(1'b1),.drfm_data(64'd22),.drfm_valid(1'b1),.dds_data(64'd33),.dds_valid(1'b1),.awg_data(64'd44),.awg_valid(1'b1),.active_mode(active),.accepted(ma),.rejected(mr),.out_data(data),.out_valid(mv));
task tick; begin @(posedge clk); #1; end endtask
integer k,expected_s,expected_c; real theta; integer pulses=0,samples=0; reg prev=0;
always @(negedge clk) if(!rst) begin
 if(busy && gsc>start && !en) $fatal(1,"NCO pauses in PRI gap");
 if(gate && pr && pinc!=48'h400000000000)$fatal(1,"chirp pulse restart");
 if(gate && !pr && pinc!=48'h400000000001)$fatal(1,"chirp increment");
 if(gate) begin samples=samples+1; if(!prev) pulses=pulses+1; end
 prev=gate;
end
initial begin
 tick; rst=0; @(negedge clk);cmd=1; tick; if(!accept)$fatal(1,"command rejected"); @(negedge clk);cmd=0; pw=99;
 repeat(10) tick;
 if(samples!=4||pulses!=2||busy)$fatal(1,"burst snapshot/count %0d %0d",samples,pulses);
 @(negedge clk);cmd=1;start=64'd256;pw=1;pri=32'h80000000;count=32'h80000000;
 tick;if(!reject||accept)$fatal(1,"wrapped train accepted");
 @(negedge clk);cmd=0;
 @(negedge clk);ne=1;nr=1; tick; if(ci!=32767||sq!=0||!ov)$fatal(1,"phase reset");
 @(negedge clk);nr=0; tick; if(ci!=0||sq!=32767)$fatal(1,"positive rotation");
 tick; if(ci!=-32767||sq!=0)$fatal(1,"half phase");
 @(negedge clk);ng=0; tick; if(ci!=0||sq!=0||!ov)$fatal(1,"zero envelope");
 // Sweep every LUT phase against an independent real-valued sine reference.
 @(negedge clk);ng=1;nr=1;np=48'h004000000000;tick;
 @(negedge clk);nr=0;
 for(k=1;k<1024;k=k+1)begin
  tick;theta=6.283185307179586*k/1024.0;
  expected_s=$rtoi(32767.0*$sin(theta));expected_c=$rtoi(32767.0*$cos(theta));
  if(sq<expected_s-1||sq>expected_s+1||ci<expected_c-1||ci>expected_c+1)$fatal(1,"LUT numeric error %0d",k);
 end
 @(negedge clk);nr=1;np=48'hc00000000000;tick;
 @(negedge clk);nr=0;tick;if(ci!=0||sq!=-32767)$fatal(1,"negative rotation");
 @(negedge clk);ne=0;tick;if(ov||ci||sq)$fatal(1,"disabled NCO");
 @(negedge clk);req=1;mode=3; tick; @(negedge clk);req=0; tick; if(active!=0)$fatal(1,"mid pulse switch");
 @(negedge clk);boundary=1;tick; if(active!=3||data!=33)$fatal(1,"boundary switch");
 @(negedge clk);safe=0;#1;if(data!=0)$fatal(1,"safety zero");
 safe=1;ota=1;req=1;mode=1;tick;if(!mr||active!=3)$fatal(1,"OTA LIVE accepted");
 $display("PASS waveform sources");$finish;
end
endmodule
