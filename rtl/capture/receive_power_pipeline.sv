// Six complex powers with two registered arithmetic stages; never stalls ADC.
// Channel order H_HIGH,H_MID,H_LOW,V_HIGH,V_MID,V_LOW. Signed extrema are exact.
module receive_power_pipeline(
 input wire clk,rst,sample_valid,time_valid,
 input wire [63:0] sample_seq,input wire [255:0] group_data,input wire [7:0] logical_good,
 output reg power_valid,output reg [63:0] power_seq,
 output wire [191:0] power_data,output reg [5:0] power_good
);
 reg valid_q;reg [63:0] seq_q;reg [5:0] good_q;
 always @(posedge clk)begin
  if(rst)begin valid_q<=0;power_valid<=0;seq_q<=0;power_seq<=0;good_q<=0;power_good<=0;end
  else begin
   valid_q<=sample_valid;power_valid<=valid_q;seq_q<=sample_seq;power_seq<=seq_q;
   good_q<={logical_good[6:4],logical_good[2:0]}&{6{sample_valid&&time_valid}};power_good<=good_q;
  end
 end
 genvar c;
 generate for(c=0;c<6;c=c+1)begin: lane
  localparam BASE=(c%3)*64+(c/3)*32;
  wire signed [15:0] i=group_data[BASE+:16],q=group_data[BASE+16+:16];
  reg [31:0] i2,q2,power_q;
  always @(posedge clk)begin
   i2<=$signed(i)*$signed(i);q2<=$signed(q)*$signed(q);power_q<=i2+q2;
  end
  assign power_data[c*32+:32]=power_q;
 end endgenerate
endmodule
