`timescale 1ns/1ps
module tb_record_stream_128;
 reg clk=0;always #2.5 clk=~clk;reg rst=1,desc_valid=0;
 wire rr,fr,ren,sv,sr,rdone,rrej,fdone,frej,rb,fb;
 reg[13:0] start_ptr;reg[14:0] sample_count;
 reg[1023:0] headers[0:0];wire[12:0] addr;reg[127:0] ram_data;
 reg[127:0] ram[0:8191];wire[127:0] word_data,payload_data;
 wire[1:0] mask;wire word_last,payload_valid,payload_ready,payload_last;wire[15:0] payload_keep;
 wire[127:0] data;wire[15:0] keep;wire valid,last;reg ready=0;
 reg[7:0] expected[0:131215];string root;
 integer startarg,countarg,nbytes,rejectarg=0,always_ready=0,dummy,i,pos=0,cycles=0,rdones=0,reads=0,samples=0;
 integer payload_streak=0,max_payload_streak=0;
 reg stalled=0;reg[127:0] olddata;reg[15:0] oldkeep;reg oldlast;reg[31:0] rng=32'hfeed1234;
 b_port_reader_128 r(.clk(clk),.rst(rst),.abort(1'b0),.desc_valid(desc_valid),.desc_ready(rr),.start_ptr(start_ptr),.sample_count(sample_count),.ram_en(ren),.ram_addr(addr),.ram_data(ram_data),.word_valid(sv),.word_ready(sr),.word_data(word_data),.word_mask(mask),.word_last(word_last),.word_first(),.word_index(),.done(rdone),.rejected(rrej),.busy(rb));
 dma_payload_packer p(.clk(clk),.rst(rst),.abort(1'b0),.s_valid(sv),.s_ready(sr),.s_data(word_data),.s_mask(mask),.s_last(word_last),.m_valid(payload_valid),.m_ready(payload_ready),.m_data(payload_data),.m_keep(payload_keep),.m_last(payload_last));
 record_formatter_128 f(.clk(clk),.rst(rst),.desc_valid(desc_valid),.desc_ready(fr),.header_data(headers[0]),.sample_count(sample_count),.payload_valid(payload_valid),.payload_ready(payload_ready),.payload_data(payload_data),.payload_keep(payload_keep),.payload_last(payload_last),.m_axis_tdata(data),.m_axis_tkeep(keep),.m_axis_tvalid(valid),.m_axis_tready(ready),.m_axis_tlast(last),.done(fdone),.rejected(frej),.busy(fb));
 always @(posedge clk)if(ren)ram_data<=ram[addr];
 always @(negedge clk)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};ready=!rst&&(always_ready||(rng[2:0]!=0&&cycles%97<75));end
 always @(posedge clk)if(!rst)begin
  cycles=cycles+1;if(cycles>100000)$fatal(1,"timeout");
  if(stalled&&(!valid||data!==olddata||keep!==oldkeep||last!==oldlast))$fatal(1,"stall instability");
  stalled=valid&&!ready;olddata=data;oldkeep=keep;oldlast=last;
  if(rdone)rdones=rdones+1;
  if(sv&&sr)samples=samples+mask[0]+mask[1];
  if(ren)reads=reads+1;
  if(payload_valid&&payload_ready)begin payload_streak=payload_streak+1;if(payload_streak>max_payload_streak)max_payload_streak=payload_streak;end else payload_streak=0;
  if(valid&&ready)begin
   if(rejectarg)$fatal(1,"invalid header emitted bytes");
   for(i=0;i<16;i=i+1)if(keep[i])begin
    if(pos>=nbytes||data[i*8+:8]!==expected[pos])$fatal(1,"byte mismatch %0d got%h expected%h",pos,data[i*8+:8],expected[pos]);pos=pos+1;
   end else if(data[i*8+:8]!==0)$fatal(1,"nonzero padding");
   if(last!==(pos==nbytes))$fatal(1,"last position");
  end
  #1;
  if(rejectarg&&frej)begin $display("PASS reject");$finish;end
  if(fdone)begin
   if(pos!=nbytes||valid||rdones!=1||samples!=countarg||reads!=(countarg+(startarg%2)+1)/2)$fatal(1,"accounting");
   if(always_ready&&countarg>100&&max_payload_streak<32)$fatal(1,"128 payload throughput %0d",max_payload_streak);
   $display("PASS B128 frame %0d bytes, %0d cycles, payload steady streak %0d",pos,cycles,max_payload_streak);$finish;
  end
 end
 initial begin
  dummy=$value$plusargs("ROOT=%s",root);dummy=$value$plusargs("START=%d",startarg);dummy=$value$plusargs("COUNT=%d",countarg);dummy=$value$plusargs("BYTES=%d",nbytes);dummy=$value$plusargs("REJECT=%d",rejectarg);dummy=$value$plusargs("ALWAYS_READY=%d",always_ready);
  $readmemh({root,"/ram.hex"},ram);$readmemh({root,"/header.hex"},headers);if(!rejectarg)$readmemh({root,"/expected.hex"},expected,0,nbytes-1);
  start_ptr=startarg;sample_count=countarg;
  repeat(3)@(negedge clk);rst=0;desc_valid=1;@(negedge clk);desc_valid=0;
 end
endmodule
