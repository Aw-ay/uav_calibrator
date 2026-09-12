# Stage 8 RF fault history

Goal: PS-readable fault-latch assertion history independent of active sources.
Architecture: RF-domain rising-edge observer on the actual interlock fault_latched, 16-entry exact-token queue, count/drop/token plus256-bit snapshot (12 result words). Snapshot words: tag0x30001, flags(time1/config2), config_version, state, normalized_inputs10, logical_outputs6, observation_gsc64. Values are observed after the fault latch assertion and are not root-cause evidence. No fabricated reason or source command association. No event for an unbound state that does not assert the actual latch. First high after coordinated hard reset is observed; hard reset clears history; capture soft reset and fault clear preserve it. Full drops new records, saturating count, tokens never wrap.
Commands20 PEEK and21 POP work before CONFIG. IRQ bit3 independent RF-registered nonempty level through two ctrl ASYNC_REG flops; reset mask1. C typed decode/submit in A53 library. No interlock behavior changes, physical binding, clock changes, new exceptions, board top or P&R. Current task only; user has authorized development without renewed permission.

- [x] Failing queue and real core command tests.
- [x] Implement RTL/contract/PS API and IRQ; test actual disarmed hard fault, clear/reassert, retained history and exact POP.
- [x] Full regression, XSim, A53, XPR update, freeze hashes, full synthesis and CDC comparison.
- [x] Archive evidence, commit on existing branch, report and pause.
