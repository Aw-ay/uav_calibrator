# Stage11: fault EVENT encoding and clock-domain transport

Batch: unified EVENT. Add a versioned64-byte fault aggregate format, generated SV/C/MATLAB constants, encoder, portable C decoder and transport wrapper (retainer -> encoder -> priority arbiter -> existing event_mailbox). Default queue16, RF125MHz/ctrl100MHz. Normal512-bit records pass unchanged. Convert held arbiter valid to a one-cycle mailbox attempt ONLY on ready; never repeatedly count backpressure as drops.

Fault aggregate tag0x40001, flags bit0 count saturation, occurrences32, reserved32, original256-bit RF fault snapshot, reserved128. Embedded snapshot tag0x30001 retains original semantics; no root-cause, RF-completion or new time validity claims. Saturation means count is a lower bound. Capture PDW ABI unchanged. C decoder validates tag/reserved/flags/count and embedded snapshot; no MMIO/IRQ adapter yet. MATLAB constants generated but no MATLAB runtime test claimed.

- [x] Missing-implementation tests for transport and C decoder.
- [x] Implement encoding, decoder and ready/valid-to-mailbox adapter; verify full queue/backpressure, stable16-word latch, exact counts/order, reset and C decode of actual SV words.
- [x] Related regression, XSim, A53 library and wrapper-only dual-clock synthesis/CDC.
- [x] Archive, commit, report remaining main-top/PS/CSR integration. No full-core synthesis/P&R.
