`timescale 1ns/1ps
module tb_aux_capture_backend;
 reg clk=0;always #4 clk=~clk;reg mem=0;always #2.5 mem=~mem;
 reg rst_n=0;reg [63:0] seq=0;always @(posedge clk)if(rst_n)seq<=seq+1;
 reg request=0,pop=0,ready=0;reg [63:0] pop_key=0;
 wire accepted,rejected,request_ready,meta_valid,pop_ok,busy;
 wire [767:0] metadata;wire [127:0] data;wire [15:0] keep,frozen,pending,replay_leased;
 wire last,valid;integer bytes=0;
 calibrator_capture_pipeline #(.PRE_SAMPLES(2),.DETECTOR_LATENCY(1),.FIFO_ADDR_W(6)) dut(
 .fine_command_valid(1'b0),.fine_command_pop(1'b0),.fine_command_token(64'd0),.fine_command_ready(),.fine_response_valid(),.fine_response_ok(),.fine_available_rf(),.fine_response_data(),.online_tops(192'd0),

 .online_valid(1'b0),.online_stats(512'd0),.online_peaks(192'd0),.online_error(8'd0),
  .clk_rf(clk),.clk_mem(mem),.rst_n(rst_n),.arm_enable(1'b1),.reset_request(1'b0),.producers_idle(1'b1),.replay_quiescent(1'b1),
  .sample_valid(1'b1),.sample_seq(seq),.group_data({seq,192'd0}),.primary_trigger(1'b0),.primary_onset(64'd0),.primary_pulse_id(64'd0),
  .eop_valid(16'd0),.eop_stop(1024'd0),.eop_generation(1024'd0),.request_valid(1'b0),.want_replay(1'b0),
  .request_key(256'd0),.frozen_noise(256'd0),.config_data(1024'd0),.headers(3072'd0),.bank_ids(6'd0),.bad_channels(6'd0),.bank_generations(192'd0),
  .ack_replay(1'b0),.ack_replay_bank(4'd0),.ack_replay_epoch(64'd0),.ack_replay_generation(64'd0),.replay_enable(16'd0),.replay_address(224'd0),
  .aux_request_valid(request),.aux_request_count(32'd8),.aux_request_tx_token(64'h123456789abcdef0),
  .aux_sample_gsc(seq*4),.aux_qualified(1'b1),.aux_context({32'd12,32'd11,32'd7,32'd3}),.aux_template_header(1024'd0),
  .aux_meta_pop(pop),.aux_meta_pop_key(pop_key),.aux_request_ready(request_ready),.aux_request_accepted(accepted),.aux_request_rejected(rejected),
  .aux_meta_valid(meta_valid),.aux_meta_data(metadata),.aux_meta_pop_ok(pop_ok),.aux_busy(busy),
  .frozen(frozen),.pending(pending),.replay_leased(replay_leased),
  .m_axis_tdata(data),.m_axis_tkeep(keep),.m_axis_tlast(last),.m_axis_tvalid(valid),.m_axis_tready(ready));
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 reg [63:0] first_seq;reg [767:0] held;
 always @(posedge mem)if(valid&&ready)begin
  if(bytes>=128)begin
   if(data[63:0]!==first_seq+(bytes-128)/8||data[127:64]!==first_seq+(bytes-128)/8+1)$fatal(1,"AUX real RAW data");
  end
  if(keep!=65535)$fatal(1,"keep");bytes=bytes+16;
  if(last&&bytes!=192)$fatal(1,"AUX actual byte count");
 end
 initial begin
  repeat(4)tick();rst_n=1;repeat(12)tick();first_seq=seq-2;
  request=1;tick();request=0;if(!accepted||rejected)$fatal(1,"AUX admission");
  repeat(30)tick();if(!meta_valid||metadata[84*8+:32]!=8||metadata[40*8+:64]!=64'h123456789abcdef0||!frozen[12]||replay_leased!=0)$fatal(1,"metadata/freeze/replay isolation");
  held=metadata;request=1;tick();request=0;if(!rejected||accepted)$fatal(1,"reserved metadata capacity");
  repeat(10)tick();if(metadata!==held)$fatal(1,"held metadata");
  pop_key=metadata[64+:64]+1;pop=1;tick();pop=0;if(!meta_valid)$fatal(1,"wrong POP consumed metadata");
  pop_key=metadata[64+:64];pop=1;tick();pop=0;if(meta_valid)$fatal(1,"exact POP failed");
  ready=1;for(integer i=0;i<500&&bytes<192;i=i+1)tick();
  repeat(20)tick();if(bytes!=192||frozen!=0||pending!=0)$fatal(1,"actual record return/rearm");
  $display("PASS AUX integrated backend real RAW upload/metadata/ownership");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
