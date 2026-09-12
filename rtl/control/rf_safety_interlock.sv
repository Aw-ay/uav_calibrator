// Logical clk_rf-domain sequencer. Board adapter supplies normalized feedback.
// All time settings are unsigned clk_rf cycles, stable while armed.
module rf_safety_interlock(
 input wire clk_rf,rst_n,binding_valid,timing_valid,arm,tx_request,
 input wire hard_fault,pll_locked,heartbeat,clear_fault,
 input wire pa_on_fb,tr_tx_fb,rx_protected_fb,
 input wire [31:0] protect_cycles,switch_cycles,pa_cycles,recovery_cycles,
 input wire [31:0] transition_timeout_cycles,watchdog_cycles,
 output reg pa_enable_req,tr_tx_req,rx_protect_req,dac_mute,
 output reg [2:0] state,output reg fault_latched,output wire unbound
);
 localparam SAFE=3'd0,RX=3'd1,TURNAROUND=3'd2,TX=3'd3,RECOVERY=3'd4;
 reg [1:0] phase;
 reg [31:0] dwell,transition_age,watchdog_age;
 wire settings_ok=timing_valid && transition_timeout_cycles!=0 && watchdog_cycles!=0;
 wire watchdog_expired=!heartbeat && watchdog_age>=watchdog_cycles-1;
 wire fatal_now=hard_fault || !pll_locked || !binding_valid || !settings_ok || watchdog_expired;
 wire transition_expired=(state==TURNAROUND || state==RECOVERY) && transition_age>=transition_timeout_cycles-1;
 wire inhibit=!rst_n || fatal_now || fault_latched;
 assign unbound=!binding_valid;
 always @* begin
  pa_enable_req=0;tr_tx_req=0;rx_protect_req=1;dac_mute=1;
  if(!inhibit) begin
   case(state)
    RX: rx_protect_req=0;
    TURNAROUND: begin tr_tx_req=phase>=1;pa_enable_req=phase==2 && arm && tx_request && tr_tx_fb && rx_protected_fb;end
    TX: begin tr_tx_req=1;pa_enable_req=arm && tx_request && pa_on_fb && tr_tx_fb && rx_protected_fb;dac_mute=!tx_request || !arm || !pa_on_fb || !tr_tx_fb || !rx_protected_fb;end
    RECOVERY: tr_tx_req=phase==0;
    default: begin end
   endcase
  end
 end
 always @(posedge clk_rf or negedge rst_n) begin
  if(!rst_n) begin state<=SAFE;phase<=0;dwell<=0;transition_age<=0;watchdog_age<=0;fault_latched<=0;end
  else begin
   if(heartbeat || !arm) watchdog_age<=0;
   else if(watchdog_age!=32'hffffffff) watchdog_age<=watchdog_age+1;
   if(state==TURNAROUND || state==RECOVERY) transition_age<=transition_age+1;
   else transition_age<=0;
   if((arm && fatal_now && binding_valid) || hard_fault || transition_expired ||
      // A requested shutdown immediately removes PA enable. Fast PA feedback
      // may fall before the next state transition; that is expected, not a fault.
      (state==TX && ((arm && tx_request && !pa_on_fb) || !tr_tx_fb || !rx_protected_fb))) fault_latched<=1;
   if(clear_fault && !arm && !hard_fault && pll_locked && settings_ok) fault_latched<=0;
   if(fatal_now || fault_latched || transition_expired) begin state<=SAFE;phase<=0;dwell<=0;end
   else case(state)
    SAFE: if(arm && !tx_request && !pa_on_fb && !tr_tx_fb) state<=RX;
    RX: begin
     dwell<=0;phase<=0;
     if(!arm) state<=SAFE;
     else if(tx_request) state<=TURNAROUND;
    end
    TURNAROUND: begin
     if(!arm || !tx_request) begin state<=RECOVERY;phase<=0;dwell<=0;transition_age<=0;end
     else case(phase)
      0: if(rx_protected_fb) begin
       if(protect_cycles==0 || dwell>=protect_cycles-1) begin phase<=1;dwell<=0;end else dwell<=dwell+1;
      end else dwell<=0;
      1: if(tr_tx_fb && rx_protected_fb) begin
       if(switch_cycles==0 || dwell>=switch_cycles-1) begin phase<=2;dwell<=0;end else dwell<=dwell+1;
      end else dwell<=0;
      2: if(pa_on_fb && tr_tx_fb && rx_protected_fb) begin
       if(pa_cycles==0 || dwell>=pa_cycles-1) begin state<=TX;dwell<=0;end else dwell<=dwell+1;
      end else dwell<=0;
      default: state<=SAFE;
     endcase
    end
    TX: if(!arm || !tx_request) begin state<=RECOVERY;phase<=0;dwell<=0;transition_age<=0;end
    RECOVERY: begin
     if(phase==0) begin
      if(!pa_on_fb) begin
       if(recovery_cycles==0 || dwell>=recovery_cycles-1) begin phase<=1;dwell<=0;end else dwell<=dwell+1;
      end else dwell<=0;
     end else if(!tr_tx_fb && !pa_on_fb) begin
      if(recovery_cycles==0 || dwell>=recovery_cycles-1) begin state<=arm?RX:SAFE;dwell<=0;end else dwell<=dwell+1;
     end else dwell<=0;
    end
    default: state<=SAFE;
   endcase
  end
 end
endmodule

