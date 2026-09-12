// RF-domain soft reset sequence. Stop NEW work immediately, but keep existing
// sample windows, statistics, qualification commits and upload consumers alive.
// All idle inputs must be synchronous, truthful drainage proofs, not requests.
module capture_reset_coordinator(
 input wire clk,rst,reset_request,
 input wire producers_idle,qualification_idle,upload_idle,replay_idle,
 input wire [63:0] owner_epoch,
 output wire owner_reset_request,block_new_work,busy,
 output reg done
);
 localparam [1:0] RUN=0,DRAIN=1,OWNER_RESET=2,HOLD=3;
 reg [1:0] state;
 reg idle_previous;
 reg [63:0] expected_epoch;
 wire drained=producers_idle&&qualification_idle&&upload_idle&&replay_idle;
 assign block_new_work=rst||reset_request||(state!=RUN);
 assign busy=block_new_work;
 assign owner_reset_request=!rst&&((state==OWNER_RESET)||(state==HOLD));
 always @(posedge clk)begin
  if(rst)begin state<=RUN;idle_previous<=0;expected_epoch<=0;done<=0;end
  else begin
   done<=0;
   case(state)
    RUN:begin
     idle_previous<=0;
     if(reset_request)state<=DRAIN;
    end
    DRAIN:begin
     idle_previous<=drained;
     if(drained&&idle_previous)begin
      expected_epoch<=owner_epoch+64'd1;state<=OWNER_RESET;idle_previous<=0;
     end
    end
    OWNER_RESET:begin
     if(owner_epoch==expected_epoch)begin state<=HOLD;done<=1;end
    end
    HOLD:if(!reset_request)state<=RUN;
    default:begin state<=DRAIN;idle_previous<=0;end
   endcase
  end
 end
endmodule
