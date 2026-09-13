// Independent observation of actual fault-latch assertions; not root-cause capture.
module rf_fault_queue #(parameter integer ADDR_W=4)(
 input wire clk,rst,fault_latched,time_valid,config_valid,pop_valid,
 input wire [31:0] config_id,input wire [2:0] rf_state,
 input wire [9:0] normalized_inputs,input wire [5:0] logical_outputs,
 input wire [63:0] gsc,pop_token,
 output wire [31:0] count,output reg [31:0] dropped,
 output wire [63:0] head_token,output wire [255:0] head_data,output wire pop_ok,output wire event_valid,output wire [255:0] record_data
);
 import instrument_control_pkg::*;
 localparam integer DEPTH=1<<ADDR_W;
 reg previous_fault;
 assign event_valid=fault_latched&&!previous_fault;
 wire [31:0] flags=(time_valid?RF_FAULT_TIME_VALID:32'd0)|(config_valid?RF_FAULT_CONFIG_VALID:32'd0);
 assign record_data={time_valid?gsc:64'd0,{26'd0,logical_outputs},{22'd0,normalized_inputs},
  {29'd0,rf_state},config_valid?config_id:32'd0,flags,RF_FAULT_TAG};
 reg [255:0] data_mem[0:DEPTH-1];reg [63:0] token_mem[0:DEPTH-1];
 reg [ADDR_W-1:0] rd,wr;reg [ADDR_W:0] occupancy;reg [63:0] next_token;reg exhausted;
 assign count={{(31-ADDR_W){1'b0}},occupancy};
 assign head_token=(!rst&&occupancy!=0)?token_mem[rd]:64'd0;
 assign head_data=(!rst&&occupancy!=0)?data_mem[rd]:256'd0;
 assign pop_ok=!rst&&pop_valid&&occupancy!=0&&pop_token==head_token;
 wire push=event_valid&&!exhausted&&(occupancy<DEPTH||pop_ok);
 always @(posedge clk)begin
  if(rst)begin
   previous_fault<=0;
   rd<=0;wr<=0;occupancy<=0;dropped<=0;next_token<=1;exhausted<=0;
  end else begin
   previous_fault<=fault_latched;
   if(push)begin
    data_mem[wr]<=record_data;token_mem[wr]<=next_token;wr<=wr+1'b1;
    if(next_token==64'hffffffffffffffff)exhausted<=1;else next_token<=next_token+1'b1;
   end
   if((event_valid&&!push)&&dropped!=32'hffffffff)dropped<=dropped+1'b1;
   if(pop_ok)rd<=rd+1'b1;
   case({push,pop_ok})2'b10:occupancy<=occupancy+1'b1;2'b01:occupancy<=occupancy-1'b1;default:begin end endcase
  end
 end
endmodule
