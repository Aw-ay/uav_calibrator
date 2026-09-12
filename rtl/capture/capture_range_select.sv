// gain_order holds three explicit logical range IDs, highest gain first in bits1:0.
// No label-derived ranking and no selection before all three frozen statistics align.
module capture_range_select(
 input wire rank_valid,input wire [5:0] gain_order,
 input wire [2:0] h_valid,v_valid,context_valid,frozen_stats_done,
 output reg selected_valid,output reg [1:0] selected_range);
 integer k;reg [1:0] r;reg valid_order;
 always @* begin
 selected_valid=0;selected_range=0;r=0;
 valid_order=(gain_order[1:0]<3)&&(gain_order[3:2]<3)&&(gain_order[5:4]<3)&&
 (gain_order[1:0]!=gain_order[3:2])&&(gain_order[1:0]!=gain_order[5:4])&&(gain_order[3:2]!=gain_order[5:4]);
 if(rank_valid && valid_order && (&frozen_stats_done)) for(k=0;k<3;k=k+1) begin
 r=gain_order[k*2+:2];
 if(!selected_valid && h_valid[r] && v_valid[r] && context_valid[r]) begin selected_valid=1;selected_range=r;end
 end
 end
endmodule
