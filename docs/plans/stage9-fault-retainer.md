# Stage 9: fault retention module

Goal: retain fault notification under downstream congestion, with explicit aggregation instead of silent loss.
Batch: unified EVENT transport. This stage provides only the per-producer RF-domain retainer. Later stages must provide priority arbitration, 512-bit event encoding/CDC transport and PS/CSR integration; run full-core synthesis when that batch is integrated. Existing rf_fault_queue, safety logic and core interfaces remain unchanged in this stage.

Interface: one-cycle in_valid attempts with opaque first-fault snapshot256, no input backpressure; out_valid/out_ready immutable snapshot plus occurrences32 and saturated flag. A head record remains stable while blocked. A separate pending aggregate retains its first snapshot, counts subsequent arrivals and flags count saturation (lower bound). Head consumption promotes pending before newer arrivals; a simultaneous new fault starts the next aggregate. If no pending aggregate exists, a simultaneous arrival replaces the consumed head. Reset is coordinated hard reset only; soft reset/clear-fault must not flush retained notifications.

Guarantee: with clock running and coordinated reset absent, every assertion contributes to an output count until saturation; at saturation count is a lower bound and the flag preserves overflow evidence. First snapshot of each aggregate retained, not all fault details. Infinite exact history is not promised. An always-blocked consumer cannot be forced to receive, but pending notification remains valid.

- [x] Directed and deterministic randomized scoreboard; demonstrate missing-module failure.
- [x] Implement retainer and validate stability, ordering/count conservation, simultaneous consume/new, saturation, reset.
- [x] Related regression, XSim and standalone125MHz synthesis; review reports and input hashes.
- [x] Document integration limits, commit and report. No full-core synthesis or board P&R.
