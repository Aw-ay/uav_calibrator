`timescale 1ns/1ps
module tb_rf_control;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,bound=0,config_valid=1,arm=0,tx=0,hard_fault=0,pll=1,hb=1,clear_fault=0;
wire pa,tr,protect,mute; wire [2:0] state; wire fault,unbound;
reg fb_pa=0,fb_tr=0,fb_protect=1;
rf_safety_interlock rf(.clk_rf(clk),.rst_n(rst_n),.binding_valid(bound),.timing_valid(config_valid),.arm(arm),.tx_request(tx),.hard_fault(hard_fault),.pll_locked(pll),.heartbeat(hb),.clear_fault(clear_fault),.pa_on_fb(fb_pa),.tr_tx_fb(fb_tr),.rx_protected_fb(fb_protect),.protect_cycles(32'd2),.switch_cycles(32'd2),.pa_cycles(32'd2),.recovery_cycles(32'd2),.transition_timeout_cycles(32'd30),.watchdog_cycles(32'd12),.pa_enable_req(pa),.tr_tx_req(tr),.rx_protect_req(protect),.dac_mute(mute),.state(state),.fault_latched(fault),.unbound(unbound));
reg reject_seen=0; always @(negedge clk) if(rejected) reject_seen=1;
reg commit=0,safe=1,aux_bound=0,ack=0,sample_tick=0;
reg [1:0] role=0,feedback_role=0;
wire [1:0] requested_role,active_role; wire busy,valid,rejected,done,aux_unbound; wire [31:0] epoch,drops;
aux_source_controller aux(.clk_rf(clk),.rst_n(rst_n),.binding_valid(aux_bound),.timing_valid(config_valid),.safe_to_switch(safe),.commit(commit),.source_shadow(role),.source_ack(ack),.source_feedback(feedback_role),.sample_tick(sample_tick),.settling_cycles(32'd2),.flush_samples(32'd42),.switch_timeout_cycles(32'd8),.source_request(requested_role),.source_active(active_role),.busy(busy),.aux_valid(valid),.rejected(rejected),.done(done),.unbound(aux_unbound),.source_epoch(epoch),.drop_count(drops));
task tick; begin @(posedge clk); #1; end endtask
task ck(input bit v,input string msg); if(!v) $fatal(1,"%s",msg); endtask
task request_aux(input [1:0] r); begin @(negedge clk);reject_seen=0;role=r;commit=1;tick();@(negedge clk);commit=0;end endtask
initial begin
 repeat(2) tick();rst_n=1;arm=1;tx=1;repeat(5)tick();ck(unbound&&!pa&&mute,"UNBOUND RF blocked");
 request_aux(1);ck(rejected&&!valid&&epoch==0,"UNBOUND AUX refuses success");
 bound=1;tx=0;tick();ck(state==1,"armed RX");tx=1;tick();ck(protect&&!tr&&!pa,"protect before switch");
 repeat(2)tick();ck(tr&&!pa,"switch before PA");fb_tr=1;repeat(2)tick();ck(pa&&mute,"PA warm-up muted");fb_pa=1;repeat(2)tick();ck(state==3&&!mute,"TX qualified");
 fb_protect=0;#1;ck(!pa&&mute,"lost protection inhibits PA without clock edge");fb_protect=1;
 tx=0;tick();ck(!pa&&tr&&protect&&mute,"recovery PA off first");fb_pa=0;repeat(2)tick();ck(!tr&&protect,"recover switch to RX");fb_tr=0;repeat(2)tick();ck(state==1&&!protect,"RX protection release");
 tx=1;repeat(7)tick(); // feedback deliberately absent
 pll=0;#1;ck(!pa&&mute,"PLL immediate logical inhibit");tick();ck(fault&&state==0,"PLL fault latch");pll=1;tx=0;repeat(2)tick();ck(fault,"fault persists");arm=0;clear_fault=1;tick();clear_fault=0;ck(!fault,"explicit disarmed clear");
 arm=1;hb=0;repeat(14)tick();ck(fault&&!pa,"Linux watchdog");arm=0;hb=1;clear_fault=1;tick();clear_fault=0;
 arm=1;tx=0;tick();tx=1;fb_protect=0;repeat(35)tick();ck(fault&&!pa,"missing protection feedback timeout");
 aux_bound=1;request_aux(1);ck(busy&&!valid&&epoch==1,"epoch increments at commit");
 ack=1;feedback_role=1;tick();ack=0;repeat(2)tick();sample_tick=1;repeat(41)tick();ck(!valid,"42 sample minimum");tick();ck(valid&&done&&active_role==1,"AUX qualified after flush");sample_tick=0;
 safe=0;request_aux(2);ck(rejected&&valid&&epoch==1,"unsafe switch rejected preserves source");safe=1;
 request_aux(2);ck(!valid&&epoch==2,"new transition invalidates old source");repeat(9)tick();ck(reject_seen&&!busy&&!valid,"missing switch ack times out");
 request_aux(1);ack=1;feedback_role=2;repeat(9)tick();ck(reject_seen&&!valid,"wrong role feedback cannot acknowledge");ack=0;
 request_aux(2);aux_bound=0;tick();ck(aux_unbound&&!busy&&!valid,"binding loss invalidates AUX");
 $display("PASS RF control: sequencing, fault latch, watchdog, timeout, binding, AUX epoch and 42 sample flush");$finish;
end
initial begin #20000;$fatal(1,"test timeout");end
endmodule



