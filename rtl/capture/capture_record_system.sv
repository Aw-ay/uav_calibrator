// Concrete ownership boundary, full ABI5 depth (16384 samples per bank).
// Trusted upstream supplies detector timing, qualification, publish/replay choice,
// and immutable semantic header fields bound to expected owner epoch/generation.
// Hold selected source valid/header/bank/identity until ready, including reset.
// Unselected stale sources must be withdrawn/rebuilt when stale_descriptor rises;
// they are never acknowledged or silently rebound to a new bank incarnation.
// Count/byte lengths are replaced from the frozen owner's descriptor.
// Completion means FIFO ownership or explicit rejected-record loss, NOT delivery.
// replay_quiescent is RF-domain proof that external replay has drained; ACK replay
// likewise requires all reads complete and an already-safe CDC token if necessary.
// Soft reset stops admission/writes but drains accepted uploads and replay reads.
// Shared hard rst_n requires external DMA isolation + both-domain quiescence;
// it discards FIFO contents and is not an independent clock-domain reset protocol.
module capture_record_system #(
 parameter integer PRE_SAMPLES=250,DETECTOR_LATENCY=0,FIFO_ADDR_W=12
)(
 input wire clk_rf,clk_mem,rst_n,arm_enable,reset_request,replay_quiescent,
 input wire sample_valid,input wire [63:0] sample_seq,input wire [255:0] group_data,
 input wire primary_trigger,input wire [63:0] primary_onset,primary_pulse_id,
 input wire aux_trigger,input wire [63:0] aux_onset,aux_pulse_id,
 input wire [15:0] eop_valid,input wire [1023:0] eop_stop,eop_generation,
 input wire [15:0] discard_pending,stats_valid,input wire [1023:0] stats_generation,
 input wire [15:0] stats_good,publish,replay_pin,
 input wire ack_replay,input wire [3:0] ack_replay_bank,
 input wire [63:0] ack_replay_epoch,ack_replay_generation,
 input wire [15:0] replay_enable,input wire [223:0] replay_address,
 output wire [1023:0] replay_data,output wire [15:0] replay_valid,
 input wire [3:0] desc_valid,output wire [3:0] desc_ready,
 input wire [4095:0] desc_headers,input wire [7:0] desc_banks,
 input wire [255:0] source_expected_epoch,source_expected_generation,
 output wire [3:0] stale_descriptor,
 output wire completion_valid,completion_error,
 output wire [63:0] completion_epoch,completion_generation,
 output wire [1:0] completion_group,completion_bank,
 output reg [31:0] record_errors,
 output wire [15:0] write_enable,armed,pending,frozen,truncated,qualified,
 output wire [1023:0] start_seq,generation,pulse_id,output wire [239:0] sample_count,
 output wire [63:0] owner_epoch,output wire [31:0] rejected_returns,dropped_triggers,
 output wire quiesce,idle_rf,primary_admitted,aux_admitted,
 output wire [127:0] m_axis_tdata,output wire [15:0] m_axis_tkeep,
 output wire m_axis_tlast,m_axis_tvalid,input wire m_axis_tready,
 output wire [FIFO_ADDR_W:0] fifo_occupancy
);
 import calibrator_contract_pkg::*;
 (* ASYNC_REG="TRUE" *) reg [1:0] rf_reset;
 always @(posedge clk_rf or negedge rst_n)
  if(!rst_n)rf_reset<=0;else rf_reset<={rf_reset[0],1'b1};
 wire rf_rst=!rf_reset[1];
 wire [3:0] upload_valid,upload_ready;
 wire [4095:0] headers;
 wire [55:0] starts;
 wire [59:0] counts;
 wire [255:0] epochs,gens;
 wire [15:0] record_enable,record_lease;
 wire [207:0] record_address;
 wire [2047:0] record_data;
 // Track the record reference separately: a replay-pinned FROZEN bank must not
 // be uploaded twice when an upstream source remains asserted after completion.
 reg [15:0] submitted;
 reg [63:0] seen_epoch;
 integer i;
 always @(posedge clk_rf)begin
  if(rf_rst)begin submitted<=0;seen_epoch<=0;record_errors<=0;end
  else begin
   seen_epoch<=owner_epoch;
   if(seen_epoch!=owner_epoch)submitted<=0;
   else begin
    for(i=0;i<16;i=i+1)if(!frozen[i])submitted[i]<=0;
    for(i=0;i<4;i=i+1)if(desc_ready[i]&&desc_valid[i])submitted[i*4+desc_banks[i*2+:2]]<=1;
   end
   if(completion_valid&&completion_error)record_errors<=record_errors+1'b1;
  end
 end
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: source
  wire [3:0] index={2'(g),desc_banks[g*2+:2]};
  wire identity_match=source_expected_epoch[g*64+:64]==owner_epoch &&
   source_expected_generation[g*64+:64]==generation[index*64+:64];
  wire eligible=frozen[index]&&!submitted[index]&&identity_match;
  assign stale_descriptor[g]=desc_valid[g]&&frozen[index]&&!identity_match;
  wire [14:0] count=sample_count[index*15+:15];
  wire [31:0] bytes={17'b0,count}*8;
  reg [1023:0] normalized_header;
  always @* begin
   normalized_header=desc_headers[g*1024+:1024];
   normalized_header[FRAME_SAMPLE_COUNT_OFFSET*8+:32]={17'b0,count};
   normalized_header[FRAME_PAYLOAD_BYTES_OFFSET*8+:32]=bytes;
   normalized_header[FRAME_RECORD_BYTES_OFFSET*8+:32]=FRAME_HEADER_BYTES+bytes+
    ((normalized_header[FRAME_QUALITY_FLAGS_OFFSET*8+:32]&QUALITY_HAS_CRC_TRAILER)!=0?FRAME_TRAILER_BYTES:0);
  end
  assign headers[g*1024+:1024]=normalized_header;
  assign starts[g*14+:14]=start_seq[index*64+:14];
  assign counts[g*15+:15]=count;
  assign epochs[g*64+:64]=owner_epoch;
  assign gens[g*64+:64]=generation[index*64+:64];
  assign upload_valid[g]=desc_valid[g]&&eligible&&!quiesce;
  // Ready can acknowledge a descriptor latched by the arbiter before quiesce.
  // Admission valid stops immediately; an already selected descriptor drains.
  assign desc_ready[g]=upload_ready[g]&&eligible;
 end endgenerate
 capture_bank_manager #(.ADDR_W(14),.PRE_SAMPLES(PRE_SAMPLES),.DETECTOR_LATENCY(DETECTOR_LATENCY)) owner(
  .clk(clk_rf),.rst(rf_rst),.arm_enable(arm_enable),.reset_request(reset_request),
  .readers_quiescent(idle_rf&&replay_quiescent),.quiesce(quiesce),
  .sample_valid(sample_valid),.sample_seq(sample_seq),
  .primary_trigger(primary_trigger),.primary_onset(primary_onset),.primary_pulse_id(primary_pulse_id),
  .aux_trigger(aux_trigger),.aux_onset(aux_onset),.aux_pulse_id(aux_pulse_id),
  .eop_valid(eop_valid),.eop_stop(eop_stop),.eop_generation(eop_generation),
  .discard_pending(discard_pending),.stats_valid(stats_valid),.stats_generation(stats_generation),
  .stats_good(stats_good),.publish(publish),.replay_pin(replay_pin),
  .ack_record(completion_valid),.ack_record_bank({completion_group,completion_bank}),
  .ack_record_epoch(completion_epoch),.ack_record_generation(completion_generation),
  .ack_replay(ack_replay),.ack_replay_bank(ack_replay_bank),.ack_replay_epoch(ack_replay_epoch),.ack_replay_generation(ack_replay_generation),
  .write_enable(write_enable),.armed(armed),.pending(pending),.frozen(frozen),.truncated(truncated),.qualified(qualified),
  .start_seq(start_seq),.generation(generation),.pulse_id(pulse_id),.sample_count(sample_count),.owner_epoch(owner_epoch),
  .rejected_returns(rejected_returns),.dropped_triggers(dropped_triggers),.primary_admitted(primary_admitted),.aux_admitted(aux_admitted));
 // Owner write_enable already suppresses writes during reset. Keep frozen A/B
 // reads alive until their consumers report quiescence; do not gate by quiesce.
 capture_bank_array #(.ADDR_W(14)) storage(
  .clk_rf(clk_rf),.clk_mem(clk_mem),.quiesce_rf(!rst_n),.quiesce_mem(!rst_n),
  .group_data(group_data),.write_enable(write_enable),.write_address(sample_seq[13:0]),
  .frozen_rf(frozen),.frozen_mem(record_lease),
  .replay_enable(replay_enable),.replay_address(replay_address),.replay_data(replay_data),.replay_valid(replay_valid),
  .record_enable(record_enable),.record_address(record_address),.record_data(record_data),.record_valid());
 record_upload_groups #(.FIFO_ADDR_W(FIFO_ADDR_W)) upload(
  .clk_rf(clk_rf),.clk_mem(clk_mem),.rst_n(rst_n),
  .desc_valid(upload_valid),.desc_ready(upload_ready),.desc_headers(headers),.desc_starts(starts),.desc_counts(counts),
  .desc_epochs(epochs),.desc_generations(gens),.desc_banks(desc_banks),
  .completion_valid(completion_valid),.completion_ready(1'b1),.completion_error(completion_error),
  .completion_epoch(completion_epoch),.completion_generation(completion_generation),.completion_group(completion_group),.completion_bank(completion_bank),
  .record_enable(record_enable),.record_lease(record_lease),.record_address(record_address),.record_data(record_data),
  .m_axis_tdata(m_axis_tdata),.m_axis_tkeep(m_axis_tkeep),.m_axis_tlast(m_axis_tlast),.m_axis_tvalid(m_axis_tvalid),
  .m_axis_tready(m_axis_tready),.fifo_occupancy(fifo_occupancy),.idle_rf(idle_rf));
endmodule
