// D05 standalone primitive, not yet connected to the capture admission path.
// One shared six-channel power stream, four independent pulse contexts.
// Power order: H_HIGH/H_MID/H_LOW/V_HIGH/V_MID/V_LOW; each power <= 2^31.
// Delay commits by 272 RF clocks: EOP hold <=256 plus <=16 transport clocks.
// The caller must deliver detector body-end, NOT capture stop including POST.
// No captured-IQ RAM port is used. A held result retains its context until ACK.
module online_body_statistics #(
 parameter integer COMMIT_DELAY=272
)(
 input wire clk,rst,sample_valid,input wire[63:0] sample_seq,
 input wire[191:0] sample_power,input wire[5:0] sample_good,
 input wire start_valid,output wire start_ready,start_eligible,output reg start_accepted,start_rejected,
 output reg[1:0] start_slot,input wire[127:0] start_key,
 input wire[63:0] onset_seq,input wire[191:0] noise_power,input wire[13:0] eop_hold,
 input wire end_valid,input wire[127:0] end_key,input wire[63:0] end_seq,
 output reg end_accepted,end_rejected,
 output wire[3:0] occupied,output reg[3:0] result_valid,input wire[3:0] result_ready,
 output wire[511:0] result_key,output reg[59:0] result_count,
 output reg[1103:0] result_energy,output reg[767:0] result_peak,result_top_signal,
 output reg[23:0] result_bad,output reg[31:0] result_error
);
 localparam AW=$clog2(COMMIT_DELAY+1),DEPTH=1<<AW;
 (* ram_style="block" *) reg[261:0] delay_mem[0:DEPTH-1];
 reg[AW-1:0] write_ptr;reg[AW:0] filled;
 reg[261:0] delayed;reg delayed_valid,previous_known,last_known;
 reg[63:0] previous_seq,last_committed;
 wire[AW-1:0] read_ptr=write_ptr-(COMMIT_DELAY-1);
 wire gap=previous_known&&(previous_seq==64'hffffffffffffffff||sample_seq!=previous_seq+64'd1);
 wire[5:0] bad_now=(!sample_valid||gap)?6'h3f:~sample_good;
 wire[63:0] delayed_seq=delayed[261:198];
 wire[191:0] delayed_power=delayed[197:6];
 wire[5:0] delayed_bad=delayed[5:0];
 reg[3:0] active,end_known;
 reg[127:0] keys[0:3];reg[63:0] onsets[0:3],ends[0:3];
 reg[191:0] noises[0:3];reg[31:0] h0[0:3][0:5],h1[0:3][0:5],h2[0:3][0:5];
 reg free_found,duplicate,end_found;reg[1:0] free_slot;
 assign occupied=active|result_valid;
 assign start_ready=free_found&&!rst;
 assign start_eligible=start_ready&&!gap&&!duplicate&&eop_hold!=0&&eop_hold<=256&&(!last_known||onset_seq>last_committed);
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: output_keys
  assign result_key[g*128+:128]=keys[g];
 end endgenerate
 always @*begin
  free_found=0;duplicate=0;end_found=0;free_slot=0;
  for(integer s=0;s<4;s=s+1)begin
   if(!occupied[s]&&!free_found)begin free_found=1;free_slot=s;end
   if(occupied[s]&&keys[s]==start_key)duplicate=1;
   if(active[s]&&!end_known[s]&&keys[s]==end_key)end_found=1;
  end
 end
 // No payload reset on inferred RAM; filled/valid prevent old reset-era data use.
 always @(posedge clk)begin
  delay_mem[write_ptr]<={sample_seq,sample_power,bad_now};
  delayed<=delay_mem[read_ptr];
 end
 integer s,c;
 reg match_end,have_end;reg[63:0] limit;
 reg[31:0] p,net_power;reg[33:0] net_sum;
 initial if(COMMIT_DELAY<272)$error("Online statistics transport budget too small");
 always @(posedge clk)begin
  if(rst)begin
   write_ptr<=0;filled<=0;delayed_valid<=0;previous_known<=0;last_known<=0;previous_seq<=0;last_committed<=0;
   active<=0;end_known<=0;result_valid<=0;start_slot<=0;start_accepted<=0;start_rejected<=0;end_accepted<=0;end_rejected<=0;
   result_count<=0;result_energy<=0;result_peak<=0;result_top_signal<=0;result_bad<=0;result_error<=0;
   for(s=0;s<4;s=s+1)begin
    keys[s]<=0;onsets[s]<=0;ends[s]<=0;noises[s]<=0;
    for(c=0;c<6;c=c+1)begin h0[s][c]<=0;h1[s][c]<=0;h2[s][c]<=0;end
   end
  end else begin
   write_ptr<=write_ptr+1'b1;
   if(filled<COMMIT_DELAY)filled<=filled+1'b1;
   delayed_valid<=filled>=COMMIT_DELAY-1;
   previous_seq<=sample_seq;previous_known<=1;
   if(delayed_valid)begin last_committed<=delayed_seq;last_known<=1;end
   start_accepted<=0;start_rejected<=0;end_accepted<=end_valid&&end_found;end_rejected<=end_valid&&!end_found;
   result_valid<=result_valid&~result_ready;
   for(s=0;s<4;s=s+1)begin
    match_end=end_valid&&active[s]&&!end_known[s]&&keys[s]==end_key;
    have_end=end_known[s]||match_end;
    limit=match_end?end_seq:ends[s];
    if(match_end)begin end_known[s]<=1;ends[s]<=end_seq;end
    if(active[s])begin
     if(gap)begin
      result_error[s*8+:8]<=8;result_bad[s*6+:6]<=6'h3f;active[s]<=0;result_valid[s]<=1;
     end else if(match_end&&(end_seq<=onsets[s]||end_seq-onsets[s]>16384||(last_known&&end_seq<=last_committed)))begin
      result_error[s*8+:8]<=(last_known&&end_seq<=last_committed)?8'd2:8'd1;
      result_bad[s*6+:6]<=6'h3f;active[s]<=0;result_valid[s]<=1;
     end else if(delayed_valid&&delayed_seq>=onsets[s])begin
      if(have_end&&delayed_seq>=limit)begin active[s]<=0;result_valid[s]<=1;end
      else if(result_count[s*15+:15]==16384)begin
       result_error[s*8+:8]<=4;result_bad[s*6+:6]<=6'h3f;active[s]<=0;result_valid[s]<=1;
      end else begin
       result_count[s*15+:15]<=result_count[s*15+:15]+1'b1;
       result_bad[s*6+:6]<=result_bad[s*6+:6]|delayed_bad;
       for(c=0;c<6;c=c+1)begin
        p=delayed_power[c*32+:32];
        result_energy[s*276+c*46+:46]<=result_energy[s*276+c*46+:46]+{14'b0,p};
        if(p>result_peak[s*192+c*32+:32])result_peak[s*192+c*32+:32]<=p;
        net_power=(p>noises[s][c*32+:32])?p-noises[s][c*32+:32]:32'b0;
        net_sum={2'b0,net_power}+{2'b0,h0[s][c]}+{2'b0,h1[s][c]}+{2'b0,h2[s][c]};
        h0[s][c]<=net_power;h1[s][c]<=h0[s][c];h2[s][c]<=h1[s][c];
        if(result_count[s*15+:15]>=3&&net_sum[33:2]>result_top_signal[s*192+c*32+:32])
         result_top_signal[s*192+c*32+:32]<=net_sum[33:2];
       end
      end
     end
    end
   end
   if(start_valid&&start_ready)begin
    if(gap||duplicate||eop_hold==0||eop_hold>256||(last_known&&onset_seq<=last_committed))start_rejected<=1;
    else begin
     start_accepted<=1;start_slot<=free_slot;active[free_slot]<=1;end_known[free_slot]<=0;
     keys[free_slot]<=start_key;onsets[free_slot]<=onset_seq;ends[free_slot]<=0;noises[free_slot]<=noise_power;
     result_count[free_slot*15+:15]<=0;result_energy[free_slot*276+:276]<=0;
     result_peak[free_slot*192+:192]<=0;result_top_signal[free_slot*192+:192]<=0;
     result_bad[free_slot*6+:6]<=0;result_error[free_slot*8+:8]<=0;
     for(c=0;c<6;c=c+1)begin h0[free_slot][c]<=0;h1[free_slot][c]<=0;h2[free_slot][c]<=0;end
    end
   end
  end
 end
endmodule
