`timescale 1ns/1ps
module tb_record_upload_groups;
 reg rf=0,mem=0,rst_n=0;
 always #4 rf=~rf;
 initial begin #0.7;forever #2.5 mem=~mem;end
 reg [3:0] dv=0;
 wire [3:0] dr;
 reg [4095:0] headers;
 reg [55:0] starts=0;
 reg [59:0] counts={4{15'd2}};
 reg [255:0] epochs={4{64'h1234000056780000}},gens;
 reg [7:0] banks;
 wire cv,ce;reg cr=1;
 wire [63:0] epoch,gen;
 wire [1:0] group,bank;
 wire [15:0] ren,lease;
 wire [207:0] addr;
 reg [2047:0] data=0;
 wire [127:0] md;
 wire [15:0] mk;
 wire ml,mv;reg mr=0;
 wire [12:0] occupancy;
 record_upload_groups dut(.clk_rf(rf),.clk_mem(mem),.rst_n(rst_n),
  .desc_valid(dv),.desc_ready(dr),.desc_headers(headers),.desc_starts(starts),.desc_counts(counts),
  .desc_epochs(epochs),.desc_generations(gens),.desc_banks(banks),
  .completion_valid(cv),.completion_ready(cr),.completion_error(ce),.completion_epoch(epoch),
  .completion_generation(gen),.completion_group(group),.completion_bank(bank),
  .record_enable(ren),.record_lease(lease),.record_address(addr),.record_data(data),
  .m_axis_tdata(md),.m_axis_tkeep(mk),.m_axis_tlast(ml),.m_axis_tvalid(mv),.m_axis_tready(mr),.fifo_occupancy(occupancy));
 reg [1023:0] h[0:3];reg [7:0] expected[0:1023];
 string root;
 integer n,total,out_bytes=0,completed=0,sent=0,lasts=0,cycle=0;
 reg [3:0] taken;
 always @(posedge mem)begin
  for(integer i=0;i<16;i=i+1)if(ren[i])begin
   if(lease!==ren || (ren&(ren-1))!=0)$fatal(1,"lease demux");
   if(addr[i*13+:13]!=0)$fatal(1,"unexpected address");
   data[i*128+:128]<={16'd6,16'd5,16'd4,16'(i),16'd3,16'd2,16'd1,16'(i)};
  end
  if(rst_n&&mv&&mr)begin
   for(integer b=0;b<16;b=b+1)if(mk[b])begin
    if(out_bytes>=total || md[b*8+:8]!==expected[out_bytes])$fatal(1,"four-group bytes mismatch %0d",out_bytes);
    out_bytes=out_bytes+1;
   end
   if(ml)lasts=lasts+1;
  end
 end
 always @(posedge rf)begin
  taken=dv&dr;
  if(rst_n)begin
   if(taken!=0)begin
    if(taken!==(4'b1<<sent))$fatal(1,"group fairness/order");sent=sent+1;
   end
   if(cv&&cr)begin
    if(ce||group!==completed[1:0]||bank!==(2'(3-completed))||epoch!==64'h1234000056780000||gen!==(64'hf000000000000100+completed))$fatal(1,"return token");
    completed=completed+1;
   end
  end
 end
 always @(negedge rf)if(rst_n)dv=dv&~taken;
 initial begin
  if(!$value$plusargs("ROOT=%s",root)||!$value$plusargs("BYTES=%d",total))$fatal(1,"arguments");
  $readmemh({root,"/headers.hex"},h);$readmemh({root,"/expected.hex"},expected);
  for(n=0;n<4;n=n+1)begin headers[n*1024+:1024]=h[n];gens[n*64+:64]=64'hf000000000000100+n;banks[n*2+:2]=2'(3-n);end
  repeat(4)@(negedge rf);rst_n=1;dv=15;
  wait(completed==4);
  if(out_bytes!=0||occupancy==0)$fatal(1,"RAW completion must preserve FIFO bytes while DMA stalled");
  while(out_bytes<total)begin @(negedge mem);cycle=cycle+1;mr=(cycle%5!=0);end
  @(negedge mem);mr=0;
  if(lasts!=4||sent!=4)$fatal(1,"record boundaries");
  $display("PASS four-group arbitration through CDC RAM FIFO with independent bytes");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
