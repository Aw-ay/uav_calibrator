// Single-domain fault notification retention. Later events in a pending group
// contribute to its count; only its first snapshot survives aggregation.
// Connect rst only to coordinated hard reset. No CDC or RF control here.
module fault_event_retainer #(parameter integer DATA_W=256,COUNT_W=32)(
 input wire clk,rst,in_valid,input wire [DATA_W-1:0] in_data,
 output wire out_valid,input wire out_ready,
 output wire [DATA_W-1:0] out_data,output wire [COUNT_W-1:0] out_occurrences,
 output wire out_saturated
);
 reg head_valid,pending_valid,head_saturated,pending_saturated;
 reg [DATA_W-1:0] head_data,pending_data;
 reg [COUNT_W-1:0] head_count,pending_count;
 localparam [COUNT_W-1:0] MAX_COUNT={COUNT_W{1'b1}};
 assign out_valid=!rst&&head_valid;
 assign out_data=out_valid?head_data:{DATA_W{1'b0}};
 assign out_occurrences=out_valid?head_count:{COUNT_W{1'b0}};
 assign out_saturated=out_valid&&head_saturated;
 always @(posedge clk)begin
  if(rst)begin
   head_valid<=0;pending_valid<=0;head_saturated<=0;pending_saturated<=0;
   head_data<=0;pending_data<=0;head_count<=0;pending_count<=0;
  end else if(!head_valid||out_ready)begin
   if(pending_valid)begin
    // Promote the complete older group. A concurrent event starts a new one.
    head_valid<=1;head_data<=pending_data;head_count<=pending_count;head_saturated<=pending_saturated;
    pending_valid<=in_valid;
    if(in_valid)begin pending_data<=in_data;pending_count<=1;pending_saturated<=0;end
   end else begin
    head_valid<=in_valid;
    if(in_valid)begin head_data<=in_data;head_count<=1;head_saturated<=0;end
   end
  end else if(in_valid)begin
   if(!pending_valid)begin
    pending_valid<=1;pending_data<=in_data;pending_count<=1;pending_saturated<=0;
   end else if(pending_count!=MAX_COUNT)pending_count<=pending_count+1'b1;
   else pending_saturated<=1;
  end
 end
endmodule
