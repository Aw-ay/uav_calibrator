module tb_tx_channel_router;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,in_valid=0,route_commit=0,safe_boundary=0;
 reg [7:0] shadow_select=0,shadow_enable=0;
 reg [63:0] in_hv=64'h4444333322221111;
 wire out_valid,commit_ack,commit_rejected;wire [7:0] lane_valid;wire [255:0] out_lanes;
 tx_channel_router dut(.*);
 task step;begin @(posedge clk);#1;end endtask
 task check_lanes(input [7:0] en,input [7:0] sel);
 begin
   if(lane_valid!==en)$fatal(1,"lane valid");
   for(integer i=0;i<8;i=i+1)
     if(out_lanes[32*i+:32]!==(en[i] ? (sel[i] ? in_hv[63:32] : in_hv[31:0]) : 32'd0))$fatal(1,"routing lane %0d",i);
 end endtask
 initial begin
   step();if(out_valid||lane_valid||out_lanes||commit_ack||commit_rejected)$fatal(1,"reset");
   @(negedge clk);rst=0;in_valid=1;step();check_lanes(0,0);
   @(negedge clk);in_valid=0;route_commit=1;safe_boundary=1;shadow_select=8'haa;shadow_enable=8'hff;
   step();if(!commit_ack||commit_rejected)$fatal(1,"accept");
   @(negedge clk);in_valid=1;route_commit=0;step();if(!out_valid)$fatal(1,"valid");check_lanes(8'hff,8'haa);
   @(negedge clk);route_commit=1;shadow_enable=0;step();if(commit_ack||!commit_rejected)$fatal(1,"active reject");check_lanes(8'hff,8'haa);
   @(negedge clk);in_valid=0;safe_boundary=0;step();if(commit_ack||!commit_rejected)$fatal(1,"unsafe reject");
   @(negedge clk);safe_boundary=1;shadow_enable=8'h5a;shadow_select=8'h0f;step();if(!commit_ack)$fatal(1,"second accept");
   @(negedge clk);route_commit=0;in_valid=1;step();check_lanes(8'h5a,8'h0f);
   @(negedge clk);in_valid=0;step();if(out_valid||lane_valid||out_lanes)$fatal(1,"bubble");
   @(negedge clk);rst=1;step();
   @(negedge clk);rst=0;in_valid=1;step();check_lanes(0,0);
   $display("PASS TX channel router: all 8 lanes, atomic commit, active/unsafe rejection, mute and reset");$finish;
 end
endmodule
