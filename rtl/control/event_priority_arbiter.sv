// Single-domain strict-priority admission into one immutable output register.
// Producers must retain valid/data until ready. Pulse-only sources need storage.
// Priority never preempts an output already presented to the consumer.
module event_priority_arbiter #(parameter integer DATA_W=512)(
 input wire clk,rst,fault_valid,normal_valid,
 input wire [DATA_W-1:0] fault_data,normal_data,
 output wire fault_ready,normal_ready,out_valid,
 input wire out_ready,output wire [DATA_W-1:0] out_data,output wire out_is_fault
);
 reg valid_hold,kind_hold;reg [DATA_W-1:0] data_hold;
 wire available=!valid_hold||out_ready;
 assign fault_ready=!rst&&available;
 assign normal_ready=!rst&&available&&!fault_valid;
 assign out_valid=!rst&&valid_hold;
 assign out_data=out_valid?data_hold:{DATA_W{1'b0}};
 assign out_is_fault=out_valid&&kind_hold;
 always @(posedge clk)begin
  if(rst)begin valid_hold<=0;kind_hold<=0;data_hold<=0;end
  else if(available)begin
   valid_hold<=fault_valid||normal_valid;
   if(fault_valid)begin data_hold<=fault_data;kind_hold<=1;end
   else if(normal_valid)begin data_hold<=normal_data;kind_hold<=0;end
  end
 end
endmodule
