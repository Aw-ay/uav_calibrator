// Twelve primary banks, one analysis engine. Metadata is frozen before owner
// publication. A selected bank runs Fine only after its RAW record reference
// returns; other banks may upload concurrently. No B-port time multiplexing of
// outstanding RAM responses and no fourth physical RAM port are introduced.
module fine_bank_service #(parameter integer PRE_SAMPLES=250)(
 input wire clk_rf,clk_mem,rst_n,input wire admit,
 input wire [5:0] bank_ids,bad_channels,input wire [255:0] request_key,frozen_noise,
 input wire [3071:0] headers,input wire [191:0] tops,peaks,input wire [511:0] online_stats,input wire [7:0] online_error,
 input wire [15:0] publish,discard_pending,analysis_leased,record_leased,truncated,
 input wire [1023:0] start_seq,generation,input wire [239:0] sample_count,
 output wire [15:0] analysis_pin,output reg ack_analysis,output reg [3:0] ack_analysis_bank,
 output reg [63:0] ack_analysis_epoch,ack_analysis_generation,output wire idle_rf,
 output wire [15:0] read_enable,read_lease,output wire [207:0] read_address,input wire [2047:0] read_data,
 output wire lost_valid,result_valid,output wire [1023:0] result_data,output reg [31:0] errors
);
 import calibrator_contract_pkg::*;
 localparam W=643;
 (* ASYNC_REG="TRUE" *) reg [1:0] rf_up,mem_up;
 always @(posedge clk_rf or negedge rst_n)if(!rst_n)rf_up<=0;else rf_up<={rf_up[0],1'b1};
 always @(posedge clk_mem or negedge rst_n)if(!rst_n)mem_up<=0;else mem_up<={mem_up[0],1'b1};
 reg [11:0] metadata_valid,selected;reg [W-1:0] metadata[0:11];reg outstanding;reg return_error_rf;reg [3:0] next_bank;integer candidate;
 wire request_busy,request_valid,request_take,return_busy,return_valid;wire [W-1:0] request_data;wire [132:0] return_data;
 reg found;reg [3:0] chosen;reg [W-1:0] dispatch;
 assign analysis_pin={4'd0,metadata_valid}&(publish|discard_pending);
 assign idle_rf=!outstanding&&analysis_leased==0;
 always @*begin
  found=0;chosen=0;
  candidate=0;
  for(integer s=0;s<12;s=s+1)begin
   candidate=next_bank+s;if(candidate>=12)candidate=candidate-12;
   if(!found&&metadata_valid[candidate]&&analysis_leased[candidate]&&!record_leased[candidate])begin chosen=candidate;found=1;end
  end
  dispatch=metadata[chosen];dispatch[563+:8]={7'd0,selected[chosen]};
 end
 wire send=rf_up[1]&&found&&!outstanding&&!request_busy;
 cdc_mailbox #(.WIDTH(W)) jobs(.src_clk(clk_rf),.dst_clk(clk_mem),.rst_n(rst_n),
  .src_send(send),.src_data(dispatch),.src_busy(request_busy),.src_done(),.dst_valid(request_valid),.dst_data(request_data),.dst_take(request_take));
 integer g,n;reg [383:0] h;reg [14:0] raw_count,ca,cb;reg [15:0] end_calc;reg [1:0] good;
 always @(posedge clk_rf)begin
  if(!rf_up[1])begin metadata_valid<=0;selected<=0;outstanding<=0;return_error_rf<=0;next_bank<=0;ack_analysis<=0;ack_analysis_bank<=0;ack_analysis_epoch<=0;ack_analysis_generation<=0;errors<=0;end
  else begin
   ack_analysis<=0;
   if(admit)for(g=0;g<3;g=g+1)begin
    n=4*g+bank_ids[g*2+:2];raw_count=sample_count[n*15+:15];
    ca=PRE_SAMPLES;end_calc=PRE_SAMPLES+{1'b0,online_stats[290:276]};cb=end_calc[14:0];
    good={!(bad_channels[g+3]||online_stats[294+g]||truncated[n]),!(bad_channels[g]||online_stats[291+g]||truncated[n])};
    if(online_error!=0||raw_count==0||ca>=raw_count||end_calc>raw_count||end_calc<=ca)begin good=0;ca=0;cb=raw_count;end
    h=0;h[31:0]=32'h00040001;h[127:64]=request_key[255:192];h[191:128]=request_key[191:128];h[255:192]=generation[n*64+:64];
    h[287:256]=headers[g*1024+FRAME_CONFIG_ID_OFFSET*8+:32];h[295:288]=g+1;h[303:296]={6'd0,bank_ids[g*2+:2]};h[383:320]=headers[g*1024+FRAME_GSC_FIRST_OFFSET*8+:64];
    metadata[n]<={h,good,{frozen_noise[195+g],frozen_noise[192+g]},
     peaks[(g+3)*32+:32],peaks[g*32+:32],tops[(g+3)*32+:32],tops[g*32+:32],
     frozen_noise[(g+3)*32+:32],frozen_noise[g*32+:32],cb,ca,raw_count,start_seq[n*64+:14],4'(n)};
    metadata_valid[n]<=1;selected[n]<=0;
   end
   for(g=0;g<12;g=g+1)if(analysis_pin[g])selected[g]<=publish[g];
   if(send)begin outstanding<=1;next_bank<=chosen==11?4'd0:chosen+1'b1;end
   if(return_valid)begin
    {ack_analysis_epoch,ack_analysis_generation,ack_analysis_bank}<=return_data[131:0];ack_analysis<=1;
    return_error_rf<=return_data[132];
   end
   // Decode only locally registered return fields. Keep outstanding until the
   // same RF edge at which the owner consumes the registered acknowledgement.
   if(ack_analysis)begin
    if(return_error_rf&&errors!=32'hffffffff)errors<=errors+1'b1;
    metadata_valid[ack_analysis_bank]<=0;outstanding<=0;
   end
  end
 end
 localparam IDLE=0,LAUNCH=1,RUN=2,RETURN=3;
 reg error_hold;reg [1:0] state;reg [W-1:0] job;
 wire engine_ready,engine_busy,engine_done,engine_error,ram_en;wire [12:0] ram_addr;
 assign request_take=mem_up[1]&&state==IDLE;
 assign lost_valid=state==RUN&&engine_done&&(engine_error||error_hold);
 wire [3:0] bank=job[3:0];
 assign read_enable=(16'b1<<bank)&{16{ram_en&&mem_up[1]}};
 assign read_lease=(16'b1<<bank)&{16{state==LAUNCH||state==RUN}};
 for(genvar x=0;x<16;x=x+1)begin assign read_address[x*13+:13]=ram_addr;end
 fine_engine engine(.clk(clk_mem),.rst(!mem_up[1]),.abort(1'b0),.job_valid(state==LAUNCH),.job_ready(engine_ready),
  .start_ptr(job[17:4]),.sample_count(job[32:18]),.coarse_start(job[47:33]),.coarse_end(job[62:48]),
  .noise(job[126:63]),.top_signal(job[190:127]),.peak_power(job[254:191]),.noise_known(job[256:255]),.source_good(job[258:257]),.job_header(job[642:259]),
  .ram_en(ram_en),.ram_addr(ram_addr),.ram_data(read_data[bank*128+:128]),
  .result_valid(result_valid),.result_ready(1'b1),.result_data(result_data),.busy(engine_busy),.done(engine_done),.error(engine_error));
 cdc_mailbox #(.WIDTH(133)) returns(.src_clk(clk_mem),.dst_clk(clk_rf),.rst_n(rst_n),
  .src_send(state==RETURN&&!return_busy),.src_data({error_hold,job[259+128+:64],job[259+192+:64],bank}),.src_busy(return_busy),.src_done(),
  .dst_valid(return_valid),.dst_data(return_data),.dst_take(rf_up[1]));
 always @(posedge clk_mem)begin
  if(!mem_up[1])begin state<=IDLE;job<=0;error_hold<=0;end
  else case(state)
   IDLE:if(request_valid)begin job<=request_data;error_hold<=0;state<=LAUNCH;end
   LAUNCH:if(engine_ready)state<=RUN;
   RUN:begin if(engine_error)error_hold<=1;if(engine_done)state<=RETURN;end
   RETURN:if(!return_busy)state<=IDLE;
  endcase
 end
endmodule
