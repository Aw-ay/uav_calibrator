// Six logical channels: H_HIGH,H_MID,H_LOW,V_HIGH,V_MID,V_LOW.
// Window membership and late-flag alignment are upstream responsibilities.
// start is a separate edge before the first sample; finish may include the
// final sample. Result remains owned until result_ready. No physical mapping,
// gain ranking, noise estimate or analog-linearity claim is made here.
module pulse_range_statistics(
 input wire clk,rst,start,sample_enable,finish,result_ready,
 input wire [63:0] pulse_id,
 input wire [95:0] iq_i,iq_q,
 input wire [5:0] sample_good,late_bad,
 output wire ready,
 output reg busy,result_valid,rejected,
 output reg [63:0] result_id,
 output reg [191:0] peak_power,
 output reg [275:0] energy,
 output reg [14:0] sample_count,
 output reg [5:0] bad_channels,
 output reg overflow
);
 assign ready=!busy&&!result_valid;
 wire [31:0] powers[0:5];
 genvar g;
 generate for(g=0;g<6;g=g+1) begin: power_lane
  wire signed [15:0] i_value=iq_i[g*16+:16],q_value=iq_q[g*16+:16];
  wire [31:0] i_squared=$signed(i_value)*$signed(i_value);
  wire [31:0] q_squared=$signed(q_value)*$signed(q_value);
  assign powers[g]=i_squared+q_squared;
 end endgenerate
 integer c;
 always @(posedge clk) begin
  if(rst) begin
   busy<=0;result_valid<=0;rejected<=0;result_id<=0;
   peak_power<=0;energy<=0;sample_count<=0;bad_channels<=0;overflow<=0;
  end else begin
   rejected<=0;
   if(result_valid&&result_ready) result_valid<=0;
   if(start) begin
    if(!ready||sample_enable||finish) rejected<=1;
    else begin
     busy<=1;result_id<=pulse_id;peak_power<=0;energy<=0;
     sample_count<=0;bad_channels<=0;overflow<=0;
    end
   end
   if(busy) begin
    bad_channels<=bad_channels|late_bad|(sample_enable?~sample_good:6'b0);
    if(sample_enable) begin
     if(sample_count==15'd16384) begin
      overflow<=1;bad_channels<=6'b111111;
     end else begin
      sample_count<=sample_count+1'b1;
      for(c=0;c<6;c=c+1) begin
       energy[c*46+:46]<=energy[c*46+:46]+{14'd0,powers[c]};
       if(powers[c]>peak_power[c*32+:32]) peak_power[c*32+:32]<=powers[c];
      end
     end
    end
    if(finish) begin
     busy<=0;result_valid<=1;
     if(sample_count==0&&!sample_enable) bad_channels<=6'b111111;
    end
   end
  end
 end
endmodule
