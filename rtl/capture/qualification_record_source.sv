// Combinational ready/valid routing from the retained qualification event to
// capture_record_system. The upstream bridge holds identity/header until ready.
// No RAW/replay ACK is produced here; descriptor acceptance is not byte delivery.
module qualification_record_source(
 input wire rst,event_valid,event_published,event_rejected,
 input wire [3:0] event_bank,
 input wire [1023:0] event_header,
 input wire [63:0] event_generation,event_epoch,
 input wire [3:0] desc_ready,stale_descriptor,
 output reg event_ready,
 output reg [3:0] desc_valid,
 output reg [4095:0] desc_headers,
 output reg [7:0] desc_banks,
 output reg [255:0] source_expected_epoch,source_expected_generation,
 output wire disposition_valid,descriptor_accepted,disposition_rejected
);
 wire eligible=event_published&&!event_rejected&&event_bank<12;
 wire stale=eligible&&stale_descriptor[event_bank[3:2]];
 assign disposition_valid=!rst&&event_valid&&event_ready;
 assign descriptor_accepted=disposition_valid&&eligible&&!stale;
 assign disposition_rejected=disposition_valid&&(event_rejected||(event_published&&(!eligible||stale)));
 always @*begin
  desc_valid=0;desc_headers=0;desc_banks=0;
  source_expected_epoch=0;source_expected_generation=0;event_ready=0;
  if(!rst&&event_valid)begin
   if(eligible)begin
    // Keep valid independent of stale: the owner derives stale from valid.
    desc_valid[event_bank[3:2]]=1;
    desc_headers[event_bank[3:2]*1024+:1024]=event_header;
    desc_banks[event_bank[3:2]*2+:2]=event_bank[1:0];
    source_expected_epoch[event_bank[3:2]*64+:64]=event_epoch;
    source_expected_generation[event_bank[3:2]*64+:64]=event_generation;
    event_ready=desc_ready[event_bank[3:2]]||stale;
   end else event_ready=1;
  end
 end
endmodule
