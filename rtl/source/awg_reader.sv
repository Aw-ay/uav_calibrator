// Sample-domain AWG core. Load port MUST cross from clk_ctrl via an external
// verified FIFO/handshake. Direct asynchronous PS connections are not supported.
// Two independent local banks: writes exclusively inactive, playback exclusively active.
module awg_reader #(parameter integer DEPTH=16384)(
 input wire clk,rst,load_begin,input wire [31:0] load_length,load_crc32c,
 input wire load_valid,input wire [63:0] load_data,output wire load_ready,
 output reg loaded,input wire commit,safe_boundary,output reg commit_ack,error,active_valid,
 input wire play,output reg playing,out_valid,out_last,output reg [63:0] out_data);
 (* ram_style="block" *) reg [63:0] bank0[0:DEPTH-1],bank1[0:DEPTH-1];
 reg [63:0] read0,read1;reg output_bank;
 reg active_bank,loading,pending;
 reg [31:0] count,expected_len,expected_crc,crc_state,active_len,read_pos;
 function automatic [31:0] crc_word(input [31:0] c,input [63:0] w);
 reg [31:0] x;integer i;begin x=c;for(i=0;i<64;i=i+1)begin
 if(x[0]^w[i])x=(x>>1)^32'h82f63b78;else x=x>>1;end crc_word=x;end endfunction
 assign load_ready=loading&&!pending;
 // Separate synchronous memory ports preserve block-RAM inference.
 always @(posedge clk)begin
  if(!rst && load_valid && load_ready)begin
   if(active_bank)bank0[count]<=load_data;else bank1[count]<=load_data;
  end
  if(playing&&!active_bank)read0<=bank0[read_pos];
  if(playing&&active_bank)read1<=bank1[read_pos];
 end
 always @* begin
  out_data=0;
  if(out_valid)out_data=output_bank?read1:read0;
 end
 always @(posedge clk)begin
  if(rst)begin active_bank<=0;loading<=0;pending<=0;count<=0;expected_len<=0;expected_crc<=0;crc_state<=32'hffffffff;active_len<=0;read_pos<=0;loaded<=0;commit_ack<=0;error<=0;active_valid<=0;playing<=0;out_valid<=0;out_last<=0;output_bank<=0;end
  else begin
   error<=0;commit_ack<=0;out_valid<=0;out_last<=0;
   if(load_begin)begin
    if(loading||pending||load_valid||commit||load_length==0||load_length>DEPTH)error<=1;
    else begin loading<=1;loaded<=0;count<=0;expected_len<=load_length;expected_crc<=load_crc32c;crc_state<=32'hffffffff;end
   end
   if(load_valid)begin
    if(!load_ready)error<=1;
    else begin
     crc_state<=crc_word(crc_state,load_data);count<=count+1;
     if(count+1==expected_len)begin loading<=0;
      if(~crc_word(crc_state,load_data)==expected_crc)loaded<=1;
      else begin loaded<=0;error<=1;end
     end
    end
   end
   if(commit)begin
    if(!loaded||loading||pending||load_begin)error<=1;
    else pending<=1;
   end
   // play has priority over commit: bank identity remains pinned through its last read.
   if(pending&&safe_boundary&&!playing&&!play)begin
    active_bank<=!active_bank;active_len<=expected_len;active_valid<=1;
    loaded<=0;pending<=0;commit_ack<=1;
   end
   if(play)begin
    if(!active_valid||playing)error<=1;
    else begin playing<=1;read_pos<=0;end
   end
   if(playing)begin
    out_valid<=1;
    output_bank<=active_bank;
    if(read_pos+1==active_len)begin out_last<=1;playing<=0;end
    else read_pos<=read_pos+1;
   end
  end
 end
endmodule
