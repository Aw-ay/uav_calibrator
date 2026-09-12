// Logical H/V fanout only; physical DAC routing/binding is external.
// Each lane must feed its own tx_cal_executor after this router.
module tx_channel_router(
 input wire clk,rst,in_valid,route_commit,safe_boundary,
 input wire [7:0] shadow_select,shadow_enable,
 input wire [63:0] in_hv,
 output reg out_valid,commit_ack,commit_rejected,
 output reg [7:0] lane_valid,output reg [255:0] out_lanes);
 reg [7:0] active_select,active_enable;
 integer lane;
 always @(posedge clk) begin
   if(rst) begin
     active_select<=0;active_enable<=0;out_valid<=0;
     commit_ack<=0;commit_rejected<=0;lane_valid<=0;out_lanes<=0;
   end else begin
     commit_ack<=0;commit_rejected<=0;
     if(route_commit) begin
       if(safe_boundary&&!in_valid) begin
         active_select<=shadow_select;active_enable<=shadow_enable;commit_ack<=1;
       end else commit_rejected<=1;
     end
     out_valid<=in_valid;lane_valid<=in_valid ? active_enable : 8'd0;
     for(lane=0;lane<8;lane=lane+1)
       out_lanes[lane*32+:32]<=in_valid&&active_enable[lane] ?
         (active_select[lane] ? in_hv[63:32] : in_hv[31:0]) : 32'd0;
   end
 end
endmodule
