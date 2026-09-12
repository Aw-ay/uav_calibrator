`timescale 1ns/1ps
module tb_axis_record_fifo;
 parameter ADDR_W=3;
 localparam DEPTH=1<<ADDR_W;
 reg clk=0,rst=1;
 always #2.5 clk=~clk;
 reg [127:0] sd=0;
 reg [15:0] sk=0;
 reg sv=0,sl=0,mr=0;
 wire sr,mv,ml;
 wire [127:0] md;
 wire [15:0] mk;
 wire [ADDR_W:0] occupancy;
 axis_record_fifo #(.ADDR_W(ADDR_W)) dut(
  .clk(clk),.rst(rst),.s_axis_tdata(sd),.s_axis_tkeep(sk),.s_axis_tlast(sl),
  .s_axis_tvalid(sv),.s_axis_tready(sr),.m_axis_tdata(md),.m_axis_tkeep(mk),
  .m_axis_tlast(ml),.m_axis_tvalid(mv),.m_axis_tready(mr),.occupancy(occupancy));
 reg [144:0] expected [0:100000];
 integer wr=0,rd=0,serial=0,cycles=0;
 reg stalled=0,source_accepted=0;
 reg [144:0] held;
 reg [31:0] random_state=32'hb3479201;
 always @(posedge clk) begin
  source_accepted=sv&&sr;
  if(rst)begin wr=0;rd=0;stalled=0;end
  else begin
   if(occupancy!==wr-rd) $fatal(1,"occupancy mismatch %d expected %d",occupancy,wr-rd);
   if(stalled && (!mv || {ml,mk,md}!==held)) $fatal(1,"AXIS changed while stalled");
   if(mv&&mr)begin
    if(rd==wr) $fatal(1,"unsolicited output");
    if({ml,mk,md}!==expected[rd]) $fatal(1,"output order/data/keep/last mismatch %d",rd);
    rd=rd+1;
   end
   if(sv&&sr)begin expected[wr]={sl,sk,sd};wr=wr+1;end
   if(wr-rd>DEPTH) $fatal(1,"exceeded exact depth");
   stalled=mv&&!mr;held={ml,mk,md};
  end
 end
 task step(input bit offer,input bit accept);
  begin
   @(negedge clk);
   // Source is held whenever the preceding edge did not accept it.
   if(!sv || source_accepted)begin
    sv=offer;
    if(offer)begin
     serial=serial+1;sd={32'hdeadcafe,32'(serial),32'(~serial),32'(serial*17)};
     sl=(serial%7==0);sk=sl ? 16'h00ff : 16'hffff;
    end
   end
   mr=accept;
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  // Fill to the specified 4096 beats, including the output register.
  repeat(DEPTH+8)step(1,0);
  @(negedge clk);
  if(sr || occupancy!=DEPTH) $fatal(1,"full boundary incorrect");
  repeat(31)step(1,0);
  for(cycles=0;cycles<DEPTH*8+1000;cycles=cycles+1)begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   step(random_state[3]|random_state[7],random_state[11]);
  end
  // Stop offering only after the held beat is accepted.
  step(0,1);repeat(DEPTH+10)step(0,1);
  @(negedge clk);if(wr!=rd||mv||occupancy!=0)$fatal(1,"drain failed");
  repeat(12)step(1,0);
  @(negedge clk);rst=1;sv=0;mr=0;
  repeat(3)@(negedge clk);rst=0;
  repeat(8)step(0,1);
  @(negedge clk);if(mv||occupancy!=0)$fatal(1,"old data after coordinated reset");
  repeat(100)step(1,1);step(0,1);repeat(DEPTH+10)step(0,1);
  @(negedge clk);if(wr!=rd)$fatal(1,"postreset drain");
  $display("PASS depth=%0d",DEPTH);$finish;
 end
 initial begin #5000000;$fatal(1,"timeout");end
endmodule
