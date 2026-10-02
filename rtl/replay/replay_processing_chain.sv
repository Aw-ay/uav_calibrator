// v0.6 RAW processing: RXCAL -> Target, with no fractional-delay filter.
// Legacy FD pins are ABI-reserved and have no profile or data-path effect.
module replay_processing_chain(
 input wire clk,rst,profile_commit,hard_fault,
 input wire [1:0] shadow_cal_valid,input wire [63:0] shadow_dc,
 input wire [71:0] shadow_gain,input wire [143:0] shadow_matrix,
 input wire [7:0] shadow_fd_phase,input wire [31:0] shadow_fd_version,
 input wire phase_valid,input wire signed [17:0] phase_i,phase_q,
 input wire in_valid,in_last,input wire [63:0] in_hv,
 output wire profile_ready,output reg profile_accepted,profile_rejected,
 output wire source_ready,busy,output reg done,cancelled,
 output wire [63:0] out_hv,output wire out_valid,out_qualified,
 output reg arithmetic_saturated,output wire [31:0] table_version
);
 localparam IDLE=0,STREAM=1,DRAIN=2;
 reg [1:0] state;reg configured;
 reg [63:0] dc;reg [71:0] gain;reg [143:0] matrix;
 reg [2:0] inflight;
 wire [1:0] cal_valid,cal_good,cal_sat;
 wire [63:0] calibrated,target_data;
 wire target_valid,target_good,target_sat;
 assign profile_ready=state==IDLE&&!(|cal_valid)&&!rst&&!hard_fault;
 wire configure=profile_commit&&profile_ready&&(&shadow_cal_valid);
 assign source_ready=configured&&!cancelled&&!hard_fault&&!rst&&!profile_commit&&(state==IDLE||state==STREAM);
 wire accept_input=in_valid&&source_ready;
 assign table_version=0;
 assign busy=state!=IDLE;
 assign out_valid=target_valid&&!cancelled&&!hard_fault&&!rst;
 assign out_qualified=out_valid&&target_good;
 assign out_hv=out_qualified?target_data:64'd0;
 genvar lane;
 generate for(lane=0;lane<2;lane=lane+1)begin: hv
  rx_cal_executor cal(.clk(clk),.rst(rst),.in_valid(accept_input),.cal_valid(configured),
   .in_i(in_hv[lane*32+:16]),.in_q(in_hv[lane*32+16+:16]),
   .dc_i(dc[lane*32+:16]),.dc_q(dc[lane*32+16+:16]),
   .gain_i(gain[lane*36+:18]),.gain_q(gain[lane*36+18+:18]),
   .out_valid(cal_valid[lane]),.out_cal_valid(cal_good[lane]),
   .out_i(calibrated[lane*32+:16]),.out_q(calibrated[lane*32+16+:16]),.saturated(cal_sat[lane]));
 end endgenerate
 target_complex_operator target(.clk(clk),.rst(rst),.in_valid(&cal_valid),
  .model_valid((&cal_good)&&phase_valid),.in_hv(calibrated),.matrix(matrix),.phase_i(phase_i),.phase_q(phase_q),
  .out_valid(target_valid),.out_model_valid(target_good),.out_hv(target_data),.saturated(target_sat));
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;configured<=0;cancelled<=0;dc<=0;gain<=0;matrix<=0;inflight<=0;
   done<=0;profile_accepted<=0;profile_rejected<=0;arithmetic_saturated<=0;
  end else begin
   inflight<={inflight[1:0],accept_input};
   done<=0;profile_accepted<=configure;profile_rejected<=profile_commit&&!configure;
   if(configure)begin configured<=1;dc<=shadow_dc;gain<=shadow_gain;matrix<=shadow_matrix;cancelled<=0;arithmetic_saturated<=0;end
   else if((|cal_sat)||target_sat)arithmetic_saturated<=1;
   if(accept_input)begin
    if(state==IDLE)arithmetic_saturated<=0;
    if(in_last)state<=DRAIN;
    else state<=STREAM;
   end
   // Track real valid stages, including input gaps; never inject filter zeros.
   if(state==DRAIN&&!(|inflight)&&!target_valid)begin
    state<=IDLE;done<=!cancelled&&!hard_fault;
   end
   if(hard_fault&&!cancelled)begin
    cancelled<=1;
    if(state!=IDLE)state<=DRAIN;
   end
  end
 end
endmodule
