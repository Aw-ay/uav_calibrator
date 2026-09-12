# Stage 7 generated-source lifecycle events

Goal: retained, attributable DDS/AWG source-drained records and PS notification.
Architecture: observe actual source acceptance, freeze gateway sequence and active TX config ID. Remember matching done and first observed cancellation cause; publish only after done and sources_drained. One observer slot follows the existing mutually exclusive source admission. Records are 10 little-endian words: tag,source,reason,command_sequence,config_id,flags,accept_gsc64,drain_gsc64. TIME_VALID requires time_valid at both observations and nonwrapping order; invalid times zero. Timestamps are observation cycles, not RF sample times. Hard reset flushes; capture soft reset preserves history. Queue16 has exact-token POP, nondestructive PEEK, saturating drops, no source backpressure, no token wrap. Overlapping malformed acceptance is counted as lost observation, original identity retained.

Reasons: normal0, STOP/reset1, safety/binding2, MUTE3. First nonzero reason retained. Safety has priority over STOP over MUTE within a cycle. Real done and drain are required even after cancellation. IRQ raw bit2 SOURCE_EVENT_AVAILABLE is an independent registered RF level with two ctrl synchronizer flops; default mask remains1. Commands18/19 expose count/drop/token plus320-bit record (14 result words). Contract generates constants; C provides submit/decode and uses existing gateway serialization.

Do not claim DAC/FIR tail retirement, analog emission, replay completion, DMA completion or board IRQ routing. No changes to RAM reader ownership, clocks, RF binding values or physical exceptions. No subagents; preserve external complex_cal_core formatting.

- [x] Failing queue/observer, real waveform sequence and C tests.
- [x] Implement monitor/queue, contract-generated PS commands, IRQ and C API.
- [x] Validate real short AWG, DDS completion, scheduled and active STOP, binding loss, history and token semantics; run full regression, selected XSim and A53 build.
- [x] Update/reopen XPR, freeze inputs, synthesize full core, inspect timing/CDC, archive, commit and pause.
