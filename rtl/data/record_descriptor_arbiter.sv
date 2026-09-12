// Four independently queued stream groups. Input producers hold valid/payload
// until ready. Selection locks under descriptor stalls and until record_done,
// which must mean the matching upload completion was consumed by the owner.
// This is record scheduling, not capture admission; it never drops a descriptor.
// Safety/event traffic uses its separate control path, not this IQ arbiter.
module record_descriptor_arbiter #(parameter integer WIDTH=1185)(
 input wire clk,rst,
 input wire [3:0] s_valid,output wire [3:0] s_ready,
 input wire [4*WIDTH-1:0] s_data,
 output wire m_valid,input wire m_ready,output reg [WIDTH-1:0] m_data,
 output reg [1:0] m_group,input wire record_done,output wire busy
);
 localparam IDLE=0,SEND=1,WAIT_DONE=2;
 reg [1:0] state,next_group;
 reg found;
 reg [1:0] choice;
 integer offset;
 always @* begin
  found=0;choice=next_group;
  for(offset=0;offset<4;offset=offset+1)begin
   if(!found&&s_valid[(int'(next_group)+offset)%4])begin
    choice=2'((int'(next_group)+offset)%4);found=1;
   end
  end
 end
 assign m_valid=(state==SEND)&&!rst;
 assign s_ready=(4'b1<<m_group)&{4{m_valid&&m_ready}};
 assign busy=(state!=IDLE);
 always @(posedge clk)begin
  if(rst)begin state<=IDLE;next_group<=0;m_group<=0;m_data<=0;end
  else case(state)
   IDLE:if(found)begin m_group<=choice;m_data<=s_data[choice*WIDTH+:WIDTH];state<=SEND;end
   SEND:if(m_ready)state<=WAIT_DONE;
   WAIT_DONE:if(record_done)begin next_group<=m_group+1'b1;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
