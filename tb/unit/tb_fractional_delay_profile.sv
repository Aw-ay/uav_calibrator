module tb_fractional_delay_profile;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,in_valid=0,profile_commit=0,safe_boundary=0;
 reg [7:0] shadow_phase=0;reg [31:0] shadow_version=0;
 reg signed [15:0] in_i=0,in_q=0;
 wire out_valid,out_coeff_valid,saturated,commit_ack,commit_rejected;
 wire signed [15:0] out_i,out_q;wire [7:0] active_phase;wire [31:0] active_version,table_version;
 fractional_delay_profile dut(.*);
 reg [64:0] vectors[0:36351];reg [1023:0] vector_file;
 localparam LATENCY=8;
 reg [64:0] expected_current=0,expected_pipe[0:LATENCY-1];
 reg [LATENCY-1:0] expected_valid=0,expected_qualified=0;
 reg configured=0;
 integer p,n,k,j;
 always @(posedge clk) begin
   if(rst || (profile_commit&&safe_boundary&&!in_valid&&shadow_version==table_version))begin
     expected_valid=0;expected_qualified=0;
     for(j=0;j<LATENCY;j=j+1)expected_pipe[j]=0;
     configured=!rst;
   end else begin
     for(j=LATENCY-1;j>0;j=j-1)expected_pipe[j]=expected_pipe[j-1];
     expected_pipe[0]=in_valid&&configured ? expected_current : 65'd0;
     expected_valid={expected_valid[LATENCY-2:0],in_valid};
     expected_qualified={expected_qualified[LATENCY-2:0],in_valid&&configured};
   end
   #1;
   if(out_valid!==expected_valid[LATENCY-1] || out_coeff_valid!==expected_qualified[LATENCY-1])$fatal(1,"pipeline valid phase%0d sample%0d",p,n);
   if(out_i!==expected_pipe[LATENCY-1][47:32] || out_q!==expected_pipe[LATENCY-1][63:48] || saturated!==expected_pipe[LATENCY-1][64])$fatal(1,"pipeline oracle phase%0d sample%0d",p,n);
 end
 task step;begin @(posedge clk);#1;end endtask
 initial begin
   if(!$value$plusargs("VECTORS=%s",vector_file))$fatal(1,"missing vectors");
   $readmemh(vector_file,vectors);
   step();@(negedge clk);rst=0;in_valid=1;step();

   @(negedge clk);in_valid=0;profile_commit=1;safe_boundary=1;shadow_version=table_version^32'h1;
   step();if(commit_ack||!commit_rejected)$fatal(1,"version mismatch");
   for(p=0;p<256;p=p+1) begin
     @(negedge clk);in_valid=0;profile_commit=1;safe_boundary=1;shadow_phase=p;shadow_version=table_version;
     step();if(!commit_ack||commit_rejected||out_valid||active_phase!==p[7:0]||active_version!==table_version)$fatal(1,"commit %0d",p);
     for(n=0;n<142;n=n+1)begin
       k=p*142+n;
       @(negedge clk);in_valid=1;profile_commit=(n==40);shadow_phase=~p[7:0];
       in_i=vectors[k][15:0];in_q=vectors[k][31:16];expected_current=vectors[k];
       step();

       if(active_phase!==p[7:0]||active_version!==table_version)$fatal(1,"frozen");
       if(n==40 && (!commit_rejected||commit_ack))$fatal(1,"active reject");
       if(n==20)begin
         @(negedge clk);in_valid=0;profile_commit=0;step();
       end
     end
     repeat(LATENCY-1)begin @(negedge clk);in_valid=0;profile_commit=0;step();end
   end
   @(negedge clk);in_valid=0;profile_commit=1;safe_boundary=0;step();if(commit_ack||!commit_rejected)$fatal(1,"unsafe reject");
   @(negedge clk);rst=1;step();if(out_valid||out_coeff_valid||active_version)$fatal(1,"reset");
   $display("PASS fractional profile: all256 phases,36352 integer vectors including62-sample tails, history reset, bubble, frozen version, commit rejection");$finish;
 end
endmodule
