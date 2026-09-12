// C05/C06 bounded detector. clk_rf=125 MHz, one HV IQ16 sample per edge.
// iq[15:0]=HI, [31:16]=HQ, [47:32]=VI, [63:48]=VQ.
// Absolute power thresholds are externally calibrated in sum(I^2+Q^2) units.
// No gain selection or implicit noise-derived/calibrated thresholds.
// Outputs register on the sample acceptance edge (zero subsequent cycles).
// End is last sample >= latched off threshold + 1. Hold delays the event only.
module pulse_detector (
 input wire clk, rst,
 input wire sample_valid,time_valid,source_valid,
 input wire [63:0] sample_seq,iq,
 input wire cfg_enable,cfg_validated,
 input wire [32:0] cfg_on_power,cfg_off_power,
 input wire [13:0] cfg_eop_hold,cfg_max_body,
 input wire noise_qualified,
 input wire [4:0] cfg_noise_shift,
 output reg active,onset_valid,event_valid,event_precise,event_truncated,
 output reg [63:0] onset_seq,event_onset_seq,event_end_seq,
 output reg [3:0] event_reason,
 output wire [32:0] sample_power,
 output reg [32:0] noise_power,
 output reg noise_valid,
 output reg [31:0] onset_count,pulse_count,abort_count
);
 localparam [3:0] GAP=4'b0001,TIME_BAD=4'b0010,SOURCE_BAD=4'b0100,MAX_BODY=4'b1000;
 wire signed [15:0] hi=iq[15:0],hq=iq[31:16],vi=iq[47:32],vq=iq[63:48];
 wire [31:0] hi2=$signed(hi)*$signed(hi),hq2=$signed(hq)*$signed(hq);
 wire [31:0] vi2=$signed(vi)*$signed(vi),vq2=$signed(vq)*$signed(vq);
 assign sample_power={1'b0,hi2}+{1'b0,hq2}+{1'b0,vi2}+{1'b0,vq2};
 wire configuration_ok=cfg_enable && cfg_validated && cfg_on_power>cfg_off_power &&
                       cfg_max_body<=14'd15000;
 wire [13:0] requested_hold=(cfg_eop_hold==0)?14'd125:cfg_eop_hold;
 wire [13:0] requested_max=(cfg_max_body==0)?14'd15000:cfg_max_body;
 reg [32:0] off_latched;
 reg [13:0] hold_latched,max_latched;
 reg [63:0] start_seq,last_body_seq,previous_seq;
 reg previous_valid,lockout;
 wire sequence_gap=previous_valid && sample_valid && (sample_seq!=previous_seq+64'd1);
 wire [3:0] quality_reason= ((!sample_valid||sequence_gap)?GAP:4'd0) |
                            (!time_valid?TIME_BAD:4'd0) | (!source_valid?SOURCE_BAD:4'd0);
 // Epoch/source generation changes must be signalled by upstream validity.
 // No event_end_seq value may be consumed as a precise end unless precise=1.
 always @(posedge clk) begin
  if(rst) begin
   active<=0;onset_valid<=0;event_valid<=0;event_precise<=0;event_truncated<=0;
   onset_seq<=0;event_onset_seq<=0;event_end_seq<=0;event_reason<=0;
   noise_power<=0;noise_valid<=0;onset_count<=0;pulse_count<=0;abort_count<=0;
   off_latched<=0;hold_latched<=125;max_latched<=15000;
   start_seq<=0;last_body_seq<=0;previous_seq<=0;previous_valid<=0;lockout<=0;
  end else begin
   onset_valid<=0;event_valid<=0;
   // Retain RF time: never create sequence numbers by counting valid samples.
   previous_valid<=sample_valid;
   if(sample_valid) previous_seq<=sample_seq;
   if(active) begin
    if(quality_reason!=0) begin
     active<=0;lockout<=1;event_valid<=1;event_precise<=0;event_truncated<=1;
     event_reason<=quality_reason;event_onset_seq<=start_seq;
     event_end_seq<=last_body_seq+64'd1;abort_count<=abort_count+1'b1;
    end else if(sample_power>=off_latched) begin
     if(sample_seq-start_seq >= {50'd0,max_latched}) begin
      active<=0;lockout<=1;event_valid<=1;event_precise<=0;event_truncated<=1;
      event_reason<=MAX_BODY;event_onset_seq<=start_seq;
      event_end_seq<=last_body_seq+64'd1;abort_count<=abort_count+1'b1;
     end else last_body_seq<=sample_seq;
    end else if(sample_seq-last_body_seq >= {50'd0,hold_latched}) begin
     active<=0;event_valid<=1;event_precise<=1;event_truncated<=0;event_reason<=0;
     event_onset_seq<=start_seq;event_end_seq<=last_body_seq+64'd1;
     pulse_count<=pulse_count+1'b1;
    end
   end else if(quality_reason!=0) begin
    // A lost sample may hide the onset too; require known off-pulse rearming.
    lockout<=1;
   end else if(configuration_ok) begin
    if(lockout) begin
     if(sample_power<cfg_off_power) lockout<=0;
    end else if(sample_power>=cfg_on_power) begin
     active<=1;onset_valid<=1;onset_seq<=sample_seq;
     start_seq<=sample_seq;last_body_seq<=sample_seq;
     off_latched<=cfg_off_power;hold_latched<=requested_hold;max_latched<=requested_max;
     onset_count<=onset_count+1'b1;
    end
    // Off-pulse qualification is an explicit external assertion, additionally
    // gated below off threshold. Noise is telemetry only, never a trigger input.
    if(noise_qualified && sample_power<cfg_off_power && !lockout) begin
     if(!noise_valid) begin noise_power<=sample_power;noise_valid<=1;end
     else if(sample_power>=noise_power)
      noise_power<=noise_power+((sample_power-noise_power)>>cfg_noise_shift);
     else noise_power<=noise_power-((noise_power-sample_power)>>cfg_noise_shift);
    end
   end
  end
 end
endmodule
