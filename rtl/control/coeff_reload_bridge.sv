// FIR-Compiler packet bridge, independent of the current fixed-coefficient FIRs.
// Payload words MUST already follow the concrete IP's generated reload order.
// CONFIG acceptance is not proof of application: active_version waits for external
// apply_confirmed from validated FIR synchronization instrumentation.
module coeff_reload_bridge #(
 parameter integer RELOAD_WIDTH=24,CONFIG_WIDTH=8,
 parameter integer MAX_RELOAD_WORDS=256,MAX_CONFIG_WORDS=16)(
 input wire clk,rst,fir_reset_done,load_begin,input wire [31:0] load_version,
 input wire [31:0] load_reload_count,load_config_count,load_crc32c,
 input wire load_valid,input wire [31:0] load_data,output wire load_ready,
 output reg loaded,input wire [1:0] bank_ref_busy,input wire commit,safe_boundary,
 input wire apply_confirmed,ip_reload_error,ip_config_error,
 output wire busy,quiesce_request,output reg commit_done,error,reset_required,
 output reg active_valid,output reg [31:0] active_version,output reg active_bank_id,
 output wire m_axis_reload_tvalid,input wire m_axis_reload_tready,
 output wire [RELOAD_WIDTH-1:0] m_axis_reload_tdata,output wire m_axis_reload_tlast,
 output wire m_axis_config_tvalid,input wire m_axis_config_tready,
 output wire [CONFIG_WIDTH-1:0] m_axis_config_tdata,output wire m_axis_config_tlast);
 localparam integer DEPTH=MAX_RELOAD_WORDS+MAX_CONFIG_WORDS;
 localparam IDLE=0,LOAD=1,WAIT_SAFE=2,RELOAD=3,CONFIG=4,WAIT_APPLY=5,FAULT=6;
 reg [2:0] state;reg ip_clean;
 reg [31:0] bank0[0:DEPTH-1],bank1[0:DEPTH-1];
 reg [31:0] candidate_version,r_count,c_count,load_pos,send_pos,expected_crc,crc_state;
 reg load_bad;
 wire ip_error=ip_reload_error||ip_config_error;
 wire [32:0] incoming_total={1'b0,load_reload_count}+{1'b0,load_config_count};
 wire [31:0] packet_word=active_bank_id?bank0[send_pos]:bank1[send_pos];
 wire bad_padding=(load_pos<r_count)?((load_data>>RELOAD_WIDTH)!=0):((load_data>>CONFIG_WIDTH)!=0);
 assign load_ready=(state==LOAD)&&!rst&&!reset_required&&!bank_ref_busy[!active_bank_id];
 assign busy=(state!=IDLE);
 assign quiesce_request=(state>=WAIT_SAFE);
 assign m_axis_reload_tvalid=(state==RELOAD)&&!rst;
 assign m_axis_reload_tdata=packet_word[RELOAD_WIDTH-1:0];
 assign m_axis_reload_tlast=(send_pos+1==r_count);
 assign m_axis_config_tvalid=(state==CONFIG)&&!rst;
 assign m_axis_config_tdata=packet_word[CONFIG_WIDTH-1:0];
 assign m_axis_config_tlast=(send_pos+1==r_count+c_count);
 function automatic [31:0] crc_word(input [31:0] c,input [31:0] w);
 reg [31:0] x;integer b;begin x=c;for(b=0;b<32;b=b+1)
 if(x[0]^w[b])x=(x>>1)^32'h82f63b78;else x=x>>1;crc_word=x;end endfunction
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;ip_clean<=0;loaded<=0;active_valid<=0;active_version<=0;active_bank_id<=0;
   candidate_version<=0;r_count<=0;c_count<=0;load_pos<=0;send_pos<=0;expected_crc<=0;crc_state<=32'hffffffff;load_bad<=0;
   commit_done<=0;error<=0;reset_required<=0;
  end else if(fir_reset_done)begin
   // Only a coordinated, actually observed FIR reset cancels AXIS transfers.
   state<=IDLE;ip_clean<=1;loaded<=0;active_valid<=0;active_version<=0;active_bank_id<=0;
   candidate_version<=0;r_count<=0;c_count<=0;load_pos<=0;send_pos<=0;expected_crc<=0;crc_state<=32'hffffffff;load_bad<=0;
   commit_done<=0;error<=0;reset_required<=0;
  end else begin
   commit_done<=0;error<=0;
   if((load_begin&&load_valid)||(load_begin&&commit)||(load_valid&&commit))error<=1;
   else begin
    if(load_begin)begin
     if(state!=IDLE||!ip_clean||reset_required||bank_ref_busy[!active_bank_id]||
        load_version==0||load_version==active_version||load_reload_count==0||load_config_count==0||
        load_reload_count>MAX_RELOAD_WORDS||load_config_count>MAX_CONFIG_WORDS||incoming_total>DEPTH)error<=1;
     else begin
      state<=LOAD;loaded<=0;load_pos<=0;load_bad<=0;
      candidate_version<=load_version;r_count<=load_reload_count;c_count<=load_config_count;
      expected_crc<=load_crc32c;crc_state<=32'hffffffff;
     end
    end
    if(load_valid)begin
     if(!load_ready)error<=1;
     else begin
      if(active_bank_id)bank0[load_pos]<=load_data;else bank1[load_pos]<=load_data;
      crc_state<=crc_word(crc_state,load_data);load_pos<=load_pos+1;
      if(bad_padding)load_bad<=1;
      if(load_pos+1==r_count+c_count)begin
       state<=IDLE;
       if(load_bad||bad_padding||~crc_word(crc_state,load_data)!=expected_crc)begin loaded<=0;error<=1;end
       else loaded<=1;
      end
     end
    end
    if(commit)begin
     if(state!=IDLE||!loaded||!ip_clean||reset_required)error<=1;
     else begin state<=WAIT_SAFE;loaded<=0;send_pos<=0;end
    end
   end
   case(state)
    WAIT_SAFE:if(safe_boundary&&!bank_ref_busy[active_bank_id]&&!bank_ref_busy[!active_bank_id])begin state<=RELOAD;send_pos<=0;end
    RELOAD:if(m_axis_reload_tready)begin
     if(m_axis_reload_tlast)begin
      if(reset_required||ip_error)state<=FAULT;
      else begin state<=CONFIG;send_pos<=r_count;active_valid<=0;end
     end else send_pos<=send_pos+1;
    end
    CONFIG:if(m_axis_config_tready)begin
     if(m_axis_config_tlast)begin
      if(reset_required||ip_error)state<=FAULT;else state<=WAIT_APPLY;
     end else send_pos<=send_pos+1;
    end
    WAIT_APPLY:if(apply_confirmed&&!reset_required&&!ip_error)begin
     active_version<=candidate_version;active_valid<=1;active_bank_id<=!active_bank_id;commit_done<=1;state<=IDLE;
    end
    default:begin end
   endcase
   if(ip_error)begin
    error<=1;reset_required<=1;active_valid<=0;ip_clean<=0;
    // Keep an already offered AXIS packet stable until its final handshake.
    // A real coordinated FIR reset may cancel it via fir_reset_done above.
    if(state!=RELOAD&&state!=CONFIG)state<=FAULT;
   end
  end
 end
endmodule
