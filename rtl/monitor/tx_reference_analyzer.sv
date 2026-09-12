// Observes filtered AUX_MID H/V IQ against actual TX event strobes.
// No replay/source-selection outputs; raw digital statistics do not imply analog calibration.
module tx_reference_analyzer(
 input wire clk,rst,tx_event_start,tx_event_end,input wire [63:0] tx_event_id,gsc,iq_hv,
 input wire [1:0] sample_valid,input wire reference_connected,source_settling,
 input wire [31:0] source_epoch,input wire [1:0] calibration_valid,
 output reg busy,report_valid,protocol_error,
 output reg [63:0] report_event_id,report_first_gsc,report_end_gsc,h_energy,v_energy,
 output reg [32:0] h_peak,v_peak,output reg [31:0] h_count,v_count,
 output reg [1:0] measurement_valid,calibrated_valid,overflow);
 reg [63:0] event_hold,first_hold;reg [31:0] epoch_hold;
 reg [63:0] energy[0:1];reg [32:0] peak[0:1];reg [31:0] count[0:1];
 reg [1:0] invalid_hold,cal_invalid,overflow_hold;
 reg [32:0] power[0:1];reg [31:0] isq,qsq;reg signed [15:0] iv,qv;
 reg [64:0] sum;integer c,j;
 always @* begin
  isq=0;qsq=0;iv=0;qv=0;
  for(c=0;c<2;c=c+1)begin
   iv=$signed(iq_hv[c*32+:16]);qv=$signed(iq_hv[c*32+16+:16]);
   isq=iv*iv;qsq=qv*qv;power[c]={1'b0,isq}+{1'b0,qsq};
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   busy<=0;report_valid<=0;protocol_error<=0;report_event_id<=0;report_first_gsc<=0;report_end_gsc<=0;
   h_energy<=0;v_energy<=0;h_peak<=0;v_peak<=0;h_count<=0;v_count<=0;measurement_valid<=0;calibrated_valid<=0;overflow<=0;
   event_hold<=0;first_hold<=0;epoch_hold<=0;invalid_hold<=0;cal_invalid<=0;overflow_hold<=0;
   for(j=0;j<2;j=j+1)begin energy[j]<=0;peak[j]<=0;count[j]<=0;end
  end else begin
   report_valid<=0;protocol_error<=0;
   if(tx_event_start&&busy)protocol_error<=1;
   if(tx_event_end&&!busy)protocol_error<=1;
   if(tx_event_start&&!busy)begin
    if(tx_event_end)protocol_error<=1;
    else begin
     busy<=1;event_hold<=tx_event_id;first_hold<=gsc;epoch_hold<=source_epoch;overflow_hold<=0;
     for(j=0;j<2;j=j+1)begin
      invalid_hold[j]<=!reference_connected||source_settling||!sample_valid[j];
      cal_invalid[j]<=!calibration_valid[j];
      if(reference_connected&&!source_settling&&sample_valid[j])begin energy[j]<=power[j];peak[j]<=power[j];count[j]<=1;end
      else begin energy[j]<=0;peak[j]<=0;count[j]<=0;end
     end
    end
   end
   if(busy)begin
    if(tx_event_end)begin
     busy<=0;report_valid<=1;report_event_id<=event_hold;report_first_gsc<=first_hold;report_end_gsc<=gsc;
     h_energy<=energy[0];v_energy<=energy[1];h_peak<=peak[0];v_peak<=peak[1];h_count<=count[0];v_count<=count[1];overflow<=overflow_hold;
     for(j=0;j<2;j=j+1)begin
      measurement_valid[j]<=!invalid_hold[j]&&!overflow_hold[j]&&count[j]!=0;
      calibrated_valid[j]<=!invalid_hold[j]&&!overflow_hold[j]&&!cal_invalid[j]&&count[j]!=0;
     end
    end else begin
     for(j=0;j<2;j=j+1)begin
      if(!reference_connected||source_settling||!sample_valid[j]||source_epoch!=epoch_hold)invalid_hold[j]<=1;
      if(!calibration_valid[j])cal_invalid[j]<=1;
      if(reference_connected&&!source_settling&&sample_valid[j])begin
       sum={1'b0,energy[j]}+{32'd0,power[j]};
       if(sum[64])begin energy[j]<=64'hffffffffffffffff;overflow_hold[j]<=1;end else energy[j]<=sum[63:0];
       if(count[j]==32'hffffffff)overflow_hold[j]<=1;else count[j]<=count[j]+1'b1;
       if(power[j]>peak[j])peak[j]<=power[j];
      end
     end
    end
   end
  end
 end
endmodule
