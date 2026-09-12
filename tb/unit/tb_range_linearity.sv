`timescale 1ns/1ps
module tb_range_linearity;
 reg [275:0] energy=0;
 reg [191:0] power_scale_q16=0;
 reg [5:0] calibration_valid=63,overlap_valid=63;
 reg tolerance_valid=1,context_valid=1,common_known=1,common_pass=1;
 reg [15:0] tolerance_q16=0;
 wire [5:0] pair_known,pair_pass,linearity_known,linearity_pass;
 range_linearity dut(.*);
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"%s",msg);endtask
 initial begin
 // Each polarization has measured energies 400,100,25 and inverse-power
 // scales 1/4,1,4. All three normalize to 100, with no dB conversion.
 for(integer p=0;p<2;p=p+1)begin
  energy[(p*3)*46+:46]=400;energy[(p*3+1)*46+:46]=100;energy[(p*3+2)*46+:46]=25;
  power_scale_q16[(p*3)*32+:32]=16384;power_scale_q16[(p*3+1)*32+:32]=65536;power_scale_q16[(p*3+2)*32+:32]=262144;
 end
 #1;check(pair_known==63&&pair_pass==63&&linearity_known==63&&linearity_pass==63,"calibrated agreement");
 common_known=0;#1;check(pair_known==63&&pair_pass==63&&linearity_known==0,"relative match cannot prove common linearity");common_known=1;
 common_pass=0;#1;check(linearity_known==63&&linearity_pass==0,"known common compression");common_pass=1;
 energy[45:0]=200;#1;
 check(pair_pass[2:0]==3'b010&&linearity_pass[2:0]==0&&linearity_pass[5:3]==7,"H compression conservatively invalidates participants, V independent");
 energy[45:0]=400;overlap_valid=6'b111011;#1;
 check(pair_known[2:0]==1&&linearity_known[2:0]==3,"no LOW overlap is unknown");overlap_valid=63;
 power_scale_q16[31:0]=0;#1;check(!linearity_known[0],"zero scale invalid");power_scale_q16[31:0]=16384;
 calibration_valid=0;#1;check(pair_known==0&&linearity_known==0,"unbound calibration");calibration_valid=63;
 tolerance_valid=0;#1;check(linearity_known==0,"unknown tolerance");tolerance_valid=1;
 context_valid=0;#1;check(pair_known==0,"context invalid");context_valid=1;
 // Exact relative error: |100-50| / max(100,50)=1/2.
 energy[45:0]=200;tolerance_q16=32768;#1;check(pair_pass==63,"tolerance equality accepted");
 tolerance_q16=32767;#1;check(pair_pass[2:0]==2,"one-unit-below tolerance rejected");
 // Full-width operands exercise the 78-bit normalization product and 94-bit
 // tolerance compare. Equal maxima must not overflow into disagreement.
 for(integer c=0;c<6;c=c+1)begin energy[c*46+:46]=46'h3fffffffffff;power_scale_q16[c*32+:32]=32'hffffffff;end
 tolerance_q16=0;#1;check(pair_pass==63,"maximum products exact equality");
 energy=0;#1;check(pair_known==0&&linearity_known==0,"zero signal cannot establish overlap");
 $display("PASS range linearity normalization compression overlap unknown common path tolerance wide arithmetic");$finish;
 end
endmodule
