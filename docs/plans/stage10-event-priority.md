# Stage 10: fault-priority event arbitration

Batch: unified EVENT transport; stage9 retainer is complete. This stage adds a single-clock, one-record elastic output arbiter and tests the retainer/arbiter path. Subsequent EVENT encoding, CDC/queue and PS/CSR integration must complete before full-core synthesis. No top-level wiring, board binding or P&R here.

Policy: when the output register can accept a new record, fault wins over normal. A normal record already presented while blocked remains immutable and is delivered before any later fault; priority does not preempt a transaction. Fault and normal inputs use valid/ready and must hold all data until accepted. Continuous faults can starve normal traffic; losses/queues for pulse-only producers remain upstream responsibilities. Output contains opaque512-bit data and a priority sideband, not a new EVENT ABI. Coordinated hard reset flushes the output and inhibits input handshakes.

- [x] Failing direct arbiter and real retainer path tests.
- [x] Implement arbiter; verify priority, backpressure, simultaneous drain/refill, stable payload, reset and fault-count conservation.
- [x] Related regression, XSim and125MHz module synthesis, evidence hashes.
- [x] Commit results and document remaining integration, without full-core synthesis.
