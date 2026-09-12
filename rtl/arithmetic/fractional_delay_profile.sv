// Frozen immutable FD63 profile. Caller's boundary must mean the previous
// record,62-sample FIR tail and8-stage pipeline have finished; an input bubble alone is insufficient.
module fractional_delay_profile(
 input wire clk,rst,in_valid,profile_commit,safe_boundary,
 input wire [7:0] shadow_phase,input wire [31:0] shadow_version,
 input wire signed [15:0] in_i,in_q,
 output wire out_valid,out_coeff_valid,saturated,
 output wire signed [15:0] out_i,out_q,
 output reg commit_ack,commit_rejected,
 output reg [7:0] active_phase,output reg [31:0] active_version,
 output wire [31:0] table_version);
 wire [1133:0] selected_coefficients;
 reg [1133:0] frozen_coefficients;
 reg configured;
 wire accept=profile_commit&&safe_boundary&&!in_valid&&(shadow_version==table_version);
 fractional_delay_coeff_rom rom(
   .phase(shadow_phase),.coefficients(selected_coefficients),.table_version(table_version));
 fractional_delay_pipelined #(.TAPS(63)) fir(
   .clk(clk),.rst(rst),.clear(accept),.in_valid(in_valid),.coeff_valid(configured),
   .in_i(in_i),.in_q(in_q),.coefficients(frozen_coefficients),
   .out_valid(out_valid),.out_coeff_valid(out_coeff_valid),.out_i(out_i),.out_q(out_q),.saturated(saturated));
 always @(posedge clk) begin
   if(rst) begin
     configured<=0;frozen_coefficients<=0;active_phase<=0;active_version<=0;
     commit_ack<=0;commit_rejected<=0;
   end else begin
     commit_ack<=accept;commit_rejected<=profile_commit&&!accept;
     if(accept) begin
       configured<=1;frozen_coefficients<=selected_coefficients;
       active_phase<=shadow_phase;active_version<=table_version;
     end
   end
 end
endmodule

