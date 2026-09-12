# Stage 6 PDW interrupt delivery

Goal: expose qualified PDW availability to PS without polling commands or changing RAW ownership.
Architecture: register nonempty in RF domain, synchronize one stable level through ASYNC_REG flops to ctrl domain. Gateway IRQ_STATUS has raw COMMAND_DONE bit0 and PDW_AVAILABLE bit1; IRQ_ENABLE masks line independently, reset=1 preserves legacy done IRQ. Existing STATUS=2 only acknowledges command DONE. PDW is cleared by exact-token POP until queue empty. PEEK, command submission, soft capture reset and masking do not discard PDW. IRQ_STATUS is read-only; unsupported enable bits reject; byte strobes apply. This is level availability, not an event counter; dropped count remains PEEK data. Short availability already consumed before synchronization need not interrupt.

Reuse command gateway register aperture at 0x4020/0x4024, generated SV/C constants; typed C mask and raw-status helpers. Extend gateway async clocks and real ADC instrument benches. No new top pin or physical mapping, no board IRQ routing or GIC/BSP assertion. No subagents. Preserve external complex_cal_core edit.

- [x] Add failing gateway register/level/masking/reset tests and actual capture IRQ test.
- [x] Implement contract/generator, gateway synchronization/masks and instrument registered source.
- [x] Add C helpers and tests for invalid masks, I/O failures and raw status.
- [x] Run full regression then selected XSim, A53 library, update/reopen XPR.
- [x] Freeze inputs, full digital synthesis, review timing/CDC, archive, commit and pause.
