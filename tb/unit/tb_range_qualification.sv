`timescale 1ns/1ps
module tb_range_qualification;
 reg [275:0] energy=0,noise_energy=0;
 reg [31:0] min_snr_q16=65536;
 reg [5:0] bad_channels=0,cal_valid=63,noise_valid=63,linearity_known=63,linearity_pass=63;
 reg context_valid=1,threshold_valid=1,rank_valid=1;
 reg [2:0] frozen_stats_done=7;
 reg [5:0] gain_order=6'b100100;
 reg [14:0] sample_count=4;
 wire [5:0] qualified;wire [47:0] reasons;
 wire selected_valid;wire [1:0] selected_range;
 range_qualification dut(.*);
 integer expected,r,cases=0;
 task check(input bit ok,input string msg);if(!ok)$fatal(1,"case %0d %s",cases,msg);endtask
 initial begin
 for(integer c=0;c<6;c=c+1)begin energy[c*46+:46]=200;noise_energy[c*46+:46]=100;end
 for(integer a=0;a<3;a=a+1)for(integer b=0;b<3;b=b+1)for(integer d=0;d<3;d=d+1)
 if(a!=b&&a!=d&&b!=d)begin
  gain_order={d[1:0],b[1:0],a[1:0]};
  for(integer mask=0;mask<64;mask=mask+1)begin
   bad_channels=mask;#1;expected=-1;
   for(integer k=0;k<3;k=k+1)begin r=(k==0)?a:((k==1)?b:d);
    if(expected==-1&&!mask[r]&&!mask[r+3])expected=r;
   end
   check(qualified==((~bad_channels)&6'h3f),"per-channel equality threshold");
   check(selected_valid==(expected!=-1),"all invalid is no selection");
   if(expected!=-1)check(selected_range==expected,"actual gain order common HV");cases=cases+1;
  end
 end
 bad_channels=0;energy[45:0]=199;#1;check(!qualified[0]&&reasons[4],"below SNR boundary");
 energy[45:0]=200;noise_valid=0;#1;check(qualified==0&&!selected_valid,"unknown noise");noise_valid=63;
 linearity_known=0;#1;check(!selected_valid&&reasons[5],"unknown linearity");linearity_known=63;
 linearity_pass=0;#1;check(!selected_valid&&reasons[6],"failed linearity");linearity_pass=63;
 cal_valid=0;#1;check(!selected_valid&&reasons[2],"unbound calibration");cal_valid=63;
 context_valid=0;#1;check(!selected_valid&&reasons[0],"context invalid");context_valid=1;
 frozen_stats_done=3;#1;check(!selected_valid,"wait all frozen");frozen_stats_done=7;
 gain_order=0;#1;check(!selected_valid,"duplicate rank invalid");gain_order=6'b100100;
 rank_valid=0;#1;check(!selected_valid,"unknown rank");rank_valid=1;
 sample_count=0;#1;check(qualified==0,"empty window");sample_count=16385;#1;check(qualified==0,"oversize window");sample_count=16384;
 for(integer c=0;c<6;c=c+1)begin energy[c*46+:46]=46'h3fffffffffff;noise_energy[c*46+:46]=46'h3fffffffffff;end
 min_snr_q16=32'hffffffff;#1;check(!selected_valid,"wide product cannot wrap");
 min_snr_q16=0;#1;check(qualified==63,"zero dB-linear excess threshold equality");
 noise_energy=0;#1;check(!selected_valid,"zero noise cannot prove SNR");
 $display("PASS range qualification 384 permutations/masks and numeric validity boundaries");$finish;
 end
endmodule
