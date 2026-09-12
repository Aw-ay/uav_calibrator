`timescale 1ns/1ps
module tb_pdw_mailbox_integration;
reg clk=0,ctrl=0,rst=1,in_valid=0,latch_head=0,pop=0;reg [63:0] pulse_id=0;
always #4 clk=~clk;always #5 ctrl=~ctrl;
wire in_ready,event_valid,event_ready,rejected,latched;wire[511:0]event_data;wire[31:0]drops,count,word_data;
reg [3:0] word_index=0;integer producer_rejections=0;
capture_pdw_writer w(.clk(clk),.rst(rst),.in_valid(in_valid),.event_ready(event_ready),.pulse_id(pulse_id),.owner_epoch(64'd1),.toa_gsc(64'd0),.energy_sum(64'd0),.config_id(32'd1),.width_ticks(32'd0),.peak_power(32'd0),.flags(32'd0),.selected_range(32'd0),.in_ready(in_ready),.event_valid(event_valid),.rejected(rejected),.event_data(event_data));
// Adapt retained valid into the mailbox's documented one-cycle attempt.
event_mailbox #(.ADDR_W(1)) m(.src_clk(clk),.ctrl_clk(ctrl),.rst_n(!rst),.event_valid(event_valid&&event_ready),.event_data(event_data),.event_ready(event_ready),.dropped_events(drops),.latch_head(latch_head),.pop(pop),.word_index(word_index),.word_data(word_data),.event_count(count),.latched_valid(latched),.command_rejected());
always @(negedge clk)if(rejected)producer_rejections=producer_rejections+1;
task tick;begin @(posedge ctrl);#1;@(negedge ctrl);end endtask
initial begin repeat(4)@(negedge clk);rst=0;repeat(4)@(negedge clk);
 for(integer n=1;n<=4;n=n+1)begin while(!in_ready)@(negedge clk);pulse_id=n;in_valid=1;@(negedge clk);in_valid=0;@(negedge clk);end
 repeat(20)@(negedge clk);
 if(drops!=0||producer_rejections!=0||!event_valid||event_ready||count!=2)$fatal(1,"bounded queue holds without false drop");
 for(integer n=1;n<=4;n=n+1)begin
  while(count==0)tick();latch_head=1;tick();latch_head=0;word_index=2;#1;
  if(!latched||word_data!=n)$fatal(1,"event ordering or corruption");
  pop=1;tick();pop=0;
 end
 repeat(20)tick();
 if(drops!=0||producer_rejections!=0||event_valid||count!=0)$fatal(1,"all four events delivered without drop");
 $display("PASS PDW mailbox integration: full queue retains event, exact delivery, no false drop");$finish;
end
initial begin #20000;$fatal(1,"timeout");end
endmodule
