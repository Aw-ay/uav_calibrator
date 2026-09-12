// Coarse capture event only. Caller supplies qualified selected H/V summaries.
module capture_pdw_writer(
 input wire clk,rst,in_valid,event_ready,
 input wire [63:0] pulse_id,owner_epoch,toa_gsc,energy_sum,
 input wire [31:0] config_id,width_ticks,peak_power,flags,selected_range,
 output wire in_ready,output reg event_valid,rejected,
 output reg [511:0] event_data
);
 import capture_event_pkg::*;
 assign in_ready=!rst&&(!event_valid||event_ready);
 always @(posedge clk)begin
  if(rst)begin event_valid<=0;event_data<=0;rejected<=0;end
  else begin
   rejected<=0;
   if(event_valid&&event_ready)event_valid<=0;
   if(in_valid)begin
    if(!in_ready)rejected<=1;
    else begin
     event_valid<=1;event_data<=0;
     event_data[EVENT_TAG_OFFSET*8+:32]<=EVENT_CAPTURE_TAG;
     event_data[EVENT_FLAGS_OFFSET*8+:32]<=flags;
     event_data[EVENT_PULSE_ID_OFFSET*8+:64]<=pulse_id;
     event_data[EVENT_OWNER_EPOCH_OFFSET*8+:64]<=owner_epoch;
     event_data[EVENT_CONFIG_ID_OFFSET*8+:32]<=config_id;
     event_data[EVENT_TOA_GSC_OFFSET*8+:64]<=(flags&EVENT_TOA_VALID)?toa_gsc:64'd0;
     event_data[EVENT_WIDTH_TICKS_OFFSET*8+:32]<=(flags&EVENT_WIDTH_VALID)?width_ticks:32'd0;
     event_data[EVENT_PEAK_POWER_OFFSET*8+:32]<=(flags&EVENT_PEAK_VALID)?peak_power:32'd0;
     event_data[EVENT_ENERGY_SUM_OFFSET*8+:64]<=(flags&EVENT_ENERGY_VALID)?energy_sum:64'd0;
     event_data[EVENT_SELECTED_RANGE_OFFSET*8+:32]<=(flags&EVENT_SELECTED_VALID)?selected_range:32'hffffffff;
    end
   end
  end
 end
endmodule
