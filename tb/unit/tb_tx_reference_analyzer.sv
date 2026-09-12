`timescale 1ns/1ps
module tb_tx_reference_analyzer;
reg clk=0;always #4 clk=~clk;reg rst=1,start=0,finish=0,connected=1,settling=0;
reg [63:0] id=19,gsc=100,iq=0;reg [1:0] valid=3,cal=3;reg [31:0] epoch=1;
wire busy,report,err;wire [63:0] rid,first,last,he,ve;wire [32:0] hp,vp;wire [31:0] hc,vc;wire [1:0] known,calok,over;
tx_reference_analyzer dut(.clk(clk),.rst(rst),.tx_event_start(start),.tx_event_end(finish),.tx_event_id(id),.gsc(gsc),.iq_hv(iq),.sample_valid(valid),.reference_connected(connected),.source_settling(settling),.source_epoch(epoch),.calibration_valid(cal),.busy(busy),.report_valid(report),.protocol_error(err),.report_event_id(rid),.report_first_gsc(first),.report_end_gsc(last),.h_energy(he),.v_energy(ve),.h_peak(hp),.v_peak(vp),.h_count(hc),.v_count(vc),.measurement_valid(known),.calibrated_valid(calok),.overflow(over));
task tick;begin @(posedge clk);#1;end endtask
initial begin
 tick;rst=0;@(negedge clk);start=1;iq={16'd0,16'd5,16'd4,16'd3};tick;
 @(negedge clk);start=0;gsc=104;iq={16'd8,16'd6,16'd0,16'd0};tick;
 @(negedge clk);finish=1;gsc=108;iq=64'hffffffffffffffff;tick;
 if(!report||rid!=19||first!=100||last!=108||he!=25||ve!=125||hp!=25||vp!=100||hc!=2||vc!=2||known!=3||calok!=3)$fatal(1,"reference statistics");
 @(negedge clk);finish=0;start=1;id=20;iq={16'h8000,16'h8000,16'h8000,16'h8000};tick;
 @(negedge clk);start=0;valid=1;cal=1;epoch=2;tick;
 @(negedge clk);finish=1;tick;if(known||calok||hp!=33'd2147483648||he!=64'd4294967296||hc!=2||vc!=1)$fatal(1,"unknown or signed fullscale");
 @(negedge clk);finish=0;start=1;valid=1;cal=1;tick;
 @(negedge clk);start=0;finish=1;tick;if(known!=1||calok!=1||hc!=1||vc!=0)$fatal(1,"H V validity isolation");
 @(negedge clk);finish=0;start=1;connected=0;tick;
 @(negedge clk);start=0;finish=1;tick;if(known||calok||hc||vc)$fatal(1,"unbound reference claimed");
 $display("PASS TX reference measured statistics");$finish;
end
endmodule
