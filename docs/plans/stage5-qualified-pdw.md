# Stage 5 qualified PDW delivery

Goal: deliver actual selected capture statistics to PS through the existing
transaction gateway, without blocking RAW or adding bank readers.

Architecture: retain scanner statistics/peaks by full context key in the four
qualification maps. Export a one-cycle observation on actual RAW descriptor
acceptance, after final qualification. The instrument formats the existing
64-byte CAPTURE_PDW ABI and queues it in the RF domain. Gateway PEEK returns
count/drop/token/event atomically; POP requires the exact head token. Hard reset
flushes the queue; capture soft reset preserves historical events and identities.

ToA = actual header GSC_FIRST + PRE*4; PW = (sample_count-PRE-POST)*4.
Instrument CONFIG cannot change while producer/pending/frozen banks exist;
therefore POST and config identity remain stable until the observation is taken.
Invalid arithmetic/identity is not reported as valid measurement. Energy and
peak cover the actual captured PRE/body/POST window of the selected H/V pair.

Tech stack: SystemVerilog, C11, Icarus, Vivado 2025.2 XSim and OOC synthesis.
Spec: event_format.json, qualification_payload.json, instrument_control.json.
Constraints: current branch/task only; no subagents, physical defaults, clock
changes, new RAM reads or timing exceptions. Preserve the external formatting edit.

- [x] Add failing qualification-retention, queue/format and real PS PDW tests.
- [x] Retain keyed statistics in qualification_publish_bridge and expose the
  accepted observation through capture_pipeline/system/dataplane.
- [x] Implement qualified_pdw_queue and generated PEEK/POP command contracts;
  add typed C decoding/submission using the existing event decoder.
- [x] Validate exact PDW against independent RAW decode, repeated peek/wrong pop,
  queue full/drop/reset and invalid measurement handling; run full regression/XSim.
- [x] Build A53 library, update/reopen existing XPR, synthesize the full digital
  instrument, archive evidence and pause.

This stage does not replace legacy CSR configuration ownership, add AUX or FIR
reload lifecycle, create the physical PS/RFDC top, route, or claim board acceptance.
