`timescale 1ns/1ps
module tb_record_bridge #(parameter USE_FIFO=0);
 reg rf=0,memclk=0;always #4 rf=~rf;initial begin #1;forever #2.5 memclk=~memclk;end
 reg rst_n=0,dv=0,cr=0;wire dr,cv,ce,ren;wire[63:0] ep,gen;wire[1:0] grp,bnk,rg,rb;
 reg[63:0] dep,dgen;reg[1:0] dg,db;
 reg[1023:0] headers[0:0],dh;reg[13:0] sp;reg[14:0] cnt;
 wire[12:0] addr;reg[127:0] ram[0:8191],rdata;wire[127:0] data;wire[15:0] keep;wire valid,last;reg ready=0;
 wire[127:0] bd;wire[15:0] bk;wire bv,bl,br;wire[12:0] occupancy;reg dma_started=0;integer full_hold=0;
 reg[7:0] expected[0:131215];string root;
 integer startarg,countarg,nbytes,rejectarg,dummy,i,pos=0,cycles=0,reads=0,final_hold=0,completed=0,roundno=0;
 reg final_seen=0,stalled=0;reg[127:0] olddata;reg[15:0] oldkeep;reg oldlast;
 reg[31:0] rng=32'hfeed1234;
 wire[15:0] enables,leases;wire[207:0] addresses;reg[2047:0] responses;
 reg tail_pause=0;
 realtime last_rf_edge=0;
 always @(posedge rf)last_rf_edge=$realtime;
 // Completion identity must enter owner logic through an RF-domain register.
 always @(ep or gen or grp or bnk or ce)if(rst_n&&$realtime>40&&$realtime!=last_rf_edge)
  $fatal(1,"completion identity changed outside receiving clock edge");
 generate if(USE_FIFO)begin: upload
 record_upload_path dut(.clk_rf(rf),.clk_mem(memclk),.rst_n(rst_n),.desc_valid(dv),.desc_ready(dr),.desc_header(dh),.desc_start(sp),.desc_count(cnt),.desc_epoch(dep),.desc_generation(dgen),.desc_group(dg),.desc_bank(db),.completion_valid(cv),.completion_ready(cr),.completion_error(ce),.completion_epoch(ep),.completion_generation(gen),.completion_group(grp),.completion_bank(bnk),.record_enable(enables),.record_lease(leases),.record_address(addresses),.record_data(responses),.m_axis_tdata(data),.m_axis_tkeep(keep),.m_axis_tvalid(valid),.m_axis_tready(ready),.m_axis_tlast(last),.fifo_occupancy(occupancy));
 assign ren=|enables;assign rg=dut.ram_group;assign rb=dut.ram_bank;assign addr=addresses[{rg,rb}*13+:13];
 assign bd=dut.stream_data;assign bk=dut.stream_keep;assign bv=dut.stream_valid;assign bl=dut.stream_last;assign br=dut.stream_ready;
 end else begin: direct
 record_dma_bridge dut(.clk_rf(rf),.clk_mem(memclk),.rst_n(rst_n),.desc_valid(dv),.desc_ready(dr),.desc_header(dh),.desc_start(sp),.desc_count(cnt),.desc_epoch(dep),.desc_generation(dgen),.desc_group(dg),.desc_bank(db),.completion_valid(cv),.completion_ready(cr),.completion_error(ce),.completion_epoch(ep),.completion_generation(gen),.completion_group(grp),.completion_bank(bnk),.ram_en(ren),.ram_addr(addr),.ram_group(rg),.ram_bank(rb),.ram_data(rdata),.m_axis_tdata(bd),.m_axis_tkeep(bk),.m_axis_tvalid(bv),.m_axis_tready(br),.m_axis_tlast(bl));
 assign data=bd;assign keep=bk;assign valid=bv;assign last=bl;assign br=ready;assign occupancy=0;
 end endgenerate
 always @(posedge memclk) if(ren)begin
  if(rejectarg)$fatal(1,"malformed header caused RAM read");
  if(rg!==((roundno/4)%4) || rb!==(roundno%4))$fatal(1,"bank token not frozen");
  if(USE_FIFO)begin
   if(enables!==(16'b1<<{rg,rb}) || leases!==enables)$fatal(1,"RAM selection/lease not one hot");
   responses<={2048{1'b1}};responses[{rg,rb}*128+:128]<=ram[addr];
  end
  rdata<=ram[addr];reads=reads+1;
 end
 always @(negedge memclk) begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};ready=rst_n && rng[2:0]!=0 && cycles%97<75;
  if(!USE_FIFO&&valid&&last&&final_hold<45)begin ready=0;final_hold=final_hold+1;end
  if(USE_FIFO&&bv&&bl)tail_pause=1;
  if(USE_FIFO&&tail_pause)ready=0;
  if(USE_FIFO&&!dma_started)begin
   ready=0;
   if(occupancy==4096)begin
    full_hold=full_hold+1;if(cv||final_seen)$fatal(1,"full FIFO released RAW early");
    if(full_hold==80)dma_started=1;
   end
  end
 end
 always @(posedge memclk) if(rst_n)begin
  if(bv&&br&&bl)final_seen=1;
  cycles=cycles+1;if(cycles>300000)$fatal(1,"timeout");
  if(stalled&&(!valid||data!==olddata||keep!==oldkeep||last!==oldlast))$fatal(1,"unstable AXIS");
  stalled=valid&&!ready;olddata=data;oldkeep=keep;oldlast=last;
  if(valid&&ready)begin
   if(rejectarg)$fatal(1,"malformed header output");
   for(i=0;i<16;i=i+1)if(keep[i])begin
    if(pos>=nbytes||data[8*i+:8]!==expected[pos])$fatal(1,"byte mismatch %0d",pos);pos=pos+1;
   end
   if(last!==(pos==nbytes))$fatal(1,"last mismatch");

  end
 end
 always @(posedge rf)if(rst_n)begin
  if(cv)begin
   if(!rejectarg&&!final_seen)$fatal(1,"lease returned before final output handshake");
   if(ep!==(64'hfedcba9876543200+roundno)||gen!==(64'h9876543212340000+roundno)||grp!==((roundno/4)%4)||bnk!==(roundno%4)||ce!==rejectarg[0])$fatal(1,"completion token/error mismatch");
  end
 end
 task run_record;begin
  @(negedge rf);dep=64'hfedcba9876543200+roundno;dgen=64'h9876543212340000+roundno;dg=(roundno/4)%4;db=roundno%4;dh=headers[0];sp=startarg;cnt=countarg;dv=1;
  do @(posedge rf);while(!dr);
  @(negedge rf);dv=0;dep=0;dgen=0;dg=0;db=0;dh=0;sp=0;cnt=0;
  wait(cv);
  if(USE_FIFO && (pos>=nbytes || occupancy==0 || full_hold!=80))$fatal(1,"FIFO ownership boundary not exercised");
  repeat(29)begin @(negedge rf);if(!cv||dr)$fatal(1,"completion lost or second lease admitted");end
  if(USE_FIFO)begin
   cr=1;@(negedge rf);cr=0;wait(!cv);tail_pause=0;wait(pos==nbytes);
  end
  if(!rejectarg&&(pos!=nbytes||reads!=(countarg+(startarg%2)+1)/2||(!USE_FIFO&&final_hold!=45)))$fatal(1,"record accounting");
  cr=1;@(negedge rf);cr=0;wait(!cv);repeat(10)@(negedge rf);
  if(cv)$fatal(1,"duplicate completion");
 end endtask
 initial begin
  dummy=$value$plusargs("ROOT=%s",root);dummy=$value$plusargs("START=%d",startarg);dummy=$value$plusargs("COUNT=%d",countarg);dummy=$value$plusargs("BYTES=%d",nbytes);dummy=$value$plusargs("REJECT=%d",rejectarg);
  $readmemh({root,"/ram.hex"},ram);$readmemh({root,"/header.hex"},headers);if(!rejectarg)$readmemh({root,"/expected.hex"},expected,0,nbytes-1);
  repeat(5)@(negedge rf);rst_n=1;
  run_record();
  // Quiesced coordinated reset only, after consumer, RAM and mailbox drain.
  rst_n=0;repeat(5)@(negedge rf);pos=0;reads=0;final_seen=0;final_hold=0;stalled=0;roundno=1;dma_started=0;full_hold=0;tail_pause=0;rst_n=1;
  run_record();
  // Reuse without reset catches toggle-mailbox acknowledgement/next-record races.
  pos=0;reads=0;final_seen=0;final_hold=0;stalled=0;roundno=2;dma_started=0;full_hold=0;tail_pause=0;
  run_record();
  for(roundno=3;roundno<(countarg==1?16:4);roundno=roundno+1)begin
   pos=0;reads=0;final_seen=0;final_hold=0;stalled=0;dma_started=0;full_hold=0;tail_pause=0;run_record();
  end
  $display("PASS records=%0d token/backpressure/reset bytes=%0d reject=%0d fifo=%0d",roundno,nbytes,rejectarg,USE_FIFO);$finish;
 end
endmodule
