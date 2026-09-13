// RF-domain observer for one actually accepted RAW replay task. Does not
// delay bank release and does not claim TX FIR or physical sink retirement.
// reader_retired is the bank-token handshake pulse, not token_valid level.
// Caller must serialize dispatch with start_ready and the downstream TX owner.
module replay_drain_observer(
 input wire clk,rst,task_started,reader_retired,dsp_busy,dsp_out_valid,drained_ready,
 input wire [1535:0] task_context,input wire [7:0] reader_status,
 output wire start_ready,output reg start_rejected,protocol_error,drained_valid,
 output reg [1535:0] drained_context,output reg [7:0] drained_status
);
 reg active,reader_seen;reg [1:0] settle;
 assign start_ready=!rst&&!active&&!drained_valid;
 always @(posedge clk)begin
  if(rst)begin
   active<=0;reader_seen<=0;settle<=0;start_rejected<=0;protocol_error<=0;
   drained_valid<=0;drained_context<=0;drained_status<=0;
  end else begin
   start_rejected<=task_started&&!start_ready;
   protocol_error<=reader_retired&&(!active||reader_seen);
   if(drained_valid&&drained_ready)drained_valid<=0;
   if(task_started&&start_ready)begin
    active<=1;reader_seen<=0;settle<=0;
    drained_context<=task_context;drained_status<=0;
   end
   if(active)begin
    if(reader_retired&&!reader_seen)begin
     reader_seen<=1;drained_status<=reader_status;
     // Last RAW valid can coincide with reader retirement while DSP busy is
     // still low. Let its registered state/output observation catch up first.
     settle<=2;
    end else if(settle!=0)settle<=settle-1'b1;
    if(reader_seen&&settle==0&&!dsp_busy&&!dsp_out_valid)begin
     active<=0;drained_valid<=1;
    end
   end
  end
 end
endmodule
