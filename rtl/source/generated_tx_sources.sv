// Actual digital source integration. Both DDS polarizations are identical,
// cos+j*sin at peak32767. Source stop is separate from downstream FIR/RF mute.
module generated_tx_sources #(parameter integer AWG_DEPTH=16384)(
 input wire clk_ctrl,clk_rf,rst_n,input wire [63:0] gsc,
 input wire stop_request,safe_boundary,
 input wire dds_cmd_valid,input wire [63:0] dds_start_gsc,
 input wire [31:0] dds_pw_samples,dds_pri_samples,dds_pulse_count,
 input wire [47:0] dds_initial_pinc,dds_chirp_step,input wire dds_reset_each_pulse,
 output wire dds_accepted,dds_rejected,dds_busy,output reg dds_done,
 output wire [63:0] dds_data,output wire dds_valid,output reg [63:0] dds_sample_gsc,
 input wire awg_ctrl_valid,input wire [1:0] awg_ctrl_op,
 input wire [31:0] awg_ctrl_length,awg_ctrl_crc32c,input wire [63:0] awg_ctrl_data,
 output wire awg_ctrl_ready,awg_ctrl_done,awg_ctrl_error,
 output wire [1:0] awg_ctrl_done_op,output wire awg_ctrl_loaded,awg_ctrl_active_valid,
 input wire awg_play,output reg awg_play_accepted,awg_play_rejected,
 output wire awg_busy,output reg awg_done,awg_done_cancelled,
 output wire [63:0] awg_data,output wire awg_valid,awg_last,
 output reg [63:0] awg_sample_gsc,output wire sources_drained);
 (* ASYNC_REG="TRUE" *) reg [1:0] rf_reset_sync;
 always @(posedge clk_rf or negedge rst_n)
  if(!rst_n)rf_reset_sync<=0;else rf_reset_sync<={rf_reset_sync[0],1'b1};
 wire rf_ready=rf_reset_sync[1];
 reg restart_inhibit,awg_cancelled,envelope_q,local_dds_rejected;
 wire burst_busy,burst_accepted,burst_rejected,burst_done,nco_enable,envelope,phase_reset,nco_valid;
 wire [47:0] pinc;wire signed [15:0] cosine,sine;
 wire raw_awg_active,raw_awg_playing,raw_awg_valid,raw_awg_last;wire [63:0] raw_awg_data;
 wire admit=rf_ready&&!stop_request&&!restart_inhibit;
 wire accept_play=awg_play&&admit&&raw_awg_active&&!raw_awg_playing&&!raw_awg_valid;
 assign sources_drained=rf_ready&&!burst_busy&&!nco_valid&&!raw_awg_playing&&!raw_awg_valid;
 assign dds_accepted=burst_accepted;
 assign dds_rejected=burst_rejected||local_dds_rejected;
 assign dds_busy=rst_n&&(burst_busy||nco_valid);
 assign awg_busy=rst_n&&(raw_awg_playing||raw_awg_valid);
 assign dds_valid=rst_n&&rf_ready&&!stop_request&&!restart_inhibit&&nco_valid&&envelope_q;
 assign dds_data=dds_valid?{sine,cosine,sine,cosine}:64'd0;
 assign awg_valid=rst_n&&rf_ready&&!stop_request&&!restart_inhibit&&!awg_cancelled&&raw_awg_valid;
 assign awg_data=awg_valid?raw_awg_data:64'd0;
 assign awg_last=awg_valid&&raw_awg_last;
 dds_burst_control burst(
  .clk(clk_rf),.rst(!rf_ready),.gsc(gsc),.cmd_valid(dds_cmd_valid&&admit),
  .start_gsc(dds_start_gsc),.pw_samples(dds_pw_samples),.pri_samples(dds_pri_samples),
  .pulse_count(dds_pulse_count),.initial_pinc(dds_initial_pinc),.chirp_step(dds_chirp_step),
  .reset_each_pulse(dds_reset_each_pulse),.abort(stop_request||restart_inhibit),
  .busy(burst_busy),.accepted(burst_accepted),.rejected(burst_rejected),.nco_enable(nco_enable),
  .envelope(envelope),.phase_reset(phase_reset),.pinc(pinc),.done(burst_done));
 dds_nco_wrapper nco(.clk(clk_rf),.rst(!rf_ready),.enable(nco_enable),.phase_reset(phase_reset),
  .pinc(pinc),.envelope(envelope),.out_valid(nco_valid),.cos_out(cosine),.sin_out(sine));
 awg_load_cdc_wrapper #(.DEPTH(AWG_DEPTH)) awg(
  .clk_ctrl(clk_ctrl),.clk_rf(clk_rf),.rst_n(rst_n),.ctrl_valid(awg_ctrl_valid),
  .ctrl_op(awg_ctrl_op),.ctrl_length(awg_ctrl_length),.ctrl_crc32c(awg_ctrl_crc32c),.ctrl_data(awg_ctrl_data),
  .ctrl_ready(awg_ctrl_ready),.ctrl_done(awg_ctrl_done),.ctrl_error(awg_ctrl_error),
  .ctrl_done_op(awg_ctrl_done_op),.ctrl_loaded(awg_ctrl_loaded),.ctrl_active_valid(awg_ctrl_active_valid),
  .safe_boundary(safe_boundary&&!raw_awg_playing&&!raw_awg_valid),.play(accept_play),
  .active_valid(raw_awg_active),.playing(raw_awg_playing),.out_valid(raw_awg_valid),
  .out_last(raw_awg_last),.out_data(raw_awg_data));
 always @(posedge clk_rf)begin
  if(!rf_ready)begin
   restart_inhibit<=0;awg_cancelled<=0;envelope_q<=0;local_dds_rejected<=0;
   dds_done<=0;dds_sample_gsc<=0;awg_sample_gsc<=0;awg_play_accepted<=0;awg_play_rejected<=0;
   awg_done<=0;awg_done_cancelled<=0;
  end else begin
   envelope_q<=envelope;
   if(nco_enable)dds_sample_gsc<=gsc;
   if(raw_awg_playing)awg_sample_gsc<=gsc;
   dds_done<=burst_done;
   awg_done<=raw_awg_valid&&raw_awg_last;
   awg_done_cancelled<=raw_awg_valid&&raw_awg_last&&(awg_cancelled||stop_request);
   local_dds_rejected<=dds_cmd_valid&&!admit;
   awg_play_accepted<=accept_play;
   awg_play_rejected<=awg_play&&!accept_play;
   if(stop_request)restart_inhibit<=1;
   else if(sources_drained)restart_inhibit<=0;
   if(stop_request&&(raw_awg_playing||raw_awg_valid))awg_cancelled<=1;
   else if(!raw_awg_playing&&!raw_awg_valid)awg_cancelled<=0;
  end
 end
endmodule
