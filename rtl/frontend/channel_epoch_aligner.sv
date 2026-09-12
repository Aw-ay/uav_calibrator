// Canonical 4SPC beat checker; does not invent/reorder missing samples.
// Every channel is compared to the independently provided common sequence/time.
module channel_epoch_aligner(
 input wire clk,rst,in_valid,input wire [63:0] expected_seq,gsc_base,
 input wire [511:0] channel_seq,channel_gsc,iq_i,iq_q,
 input wire [7:0] channel_valid,channel_mts_locked,
 input wire common_clock_good,common_mts_good,input wire [1:0] aux_switch_event,aux_settling,
 output reg out_valid,output reg [63:0] out_seq,out_gsc,output reg [511:0] out_i,out_q,
 output reg [7:0] valid_mask,output wire primary_valid,output reg [7:0] mismatch_mask,
 output reg common_fault,output reg [31:0] clock_epoch,output reg [63:0] aux_source_epoch);
 reg previous_common_good;reg [7:0] mismatch,mask;integer c;
 wire common_good=common_clock_good&&common_mts_good;
 assign primary_valid=out_valid&&((valid_mask&8'h77)==8'h77);
 always @* begin
  mismatch=0;
  for(c=0;c<8;c=c+1)
   if(channel_seq[c*64+:64]!=expected_seq||channel_gsc[c*64+:64]!=gsc_base)mismatch[c]=1;
  mask=channel_valid&channel_mts_locked&~mismatch;
  if(aux_switch_event[0]||aux_settling[0])mask[3]=0;
  if(aux_switch_event[1]||aux_settling[1])mask[7]=0;
  if(!common_good||!in_valid)mask=0;
 end
 always @(posedge clk)begin
  if(rst)begin out_valid<=0;out_seq<=0;out_gsc<=0;out_i<=0;out_q<=0;valid_mask<=0;mismatch_mask<=0;common_fault<=0;clock_epoch<=0;aux_source_epoch<=0;previous_common_good<=1;end
  else begin
   previous_common_good<=common_good;common_fault<=!common_good;
   if(previous_common_good&&!common_good)clock_epoch<=clock_epoch+1'b1;
   if(aux_switch_event[0])aux_source_epoch[31:0]<=aux_source_epoch[31:0]+1'b1;
   if(aux_switch_event[1])aux_source_epoch[63:32]<=aux_source_epoch[63:32]+1'b1;
   out_valid<=in_valid;valid_mask<=mask;
   mismatch_mask<=in_valid?mismatch:8'd0;
   if(in_valid)begin out_seq<=expected_seq;out_gsc<=gsc_base;out_i<=iq_i;out_q<=iq_q;end
  end
 end
endmodule
