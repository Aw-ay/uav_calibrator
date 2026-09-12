# Stage 4 waveform command delivery

Goal: complete typed PS DDS/AWG submission and verify the real command gateway,
source lifecycle, and digital DAC path in calibrator_instrument_core.

Architecture: keep the existing single-inflight gateway and actual DDS/AWG
engines. Reject operations that cannot finish without a later gateway command;
never leave STOP behind an indefinitely pending AWG bank commit. Retain the
independent inactive-bank load and safe-boundary commit contract.

Tech stack: SystemVerilog, Icarus, Vivado 2025.2 XSim/OOC synthesis, C11 host and A53.
Spec: contracts/instrument_control.json, docs/instrument-command-interface.md.
Global constraints: current branch/task only, no physical binding defaults,
no clock or timing-exception changes, preserve external complex_cal_core edit.
Execute inline; user explicitly forbids subagents and repeated approval gates.

- [x] Add integrated DDS/AWG bench: exact source samples/GSC, rejection paths,
  bad CRC retaining active table, safe commit, STOP and UNBOUND zero-code output.
- [x] Reproduce any integration failure before fixing it; record red evidence.
- [x] Add typed C waveform API with argument checking, exact payload packing,
  CRC, no automatic retry, host tests and A53 compile.
- [x] Run full regression and the new XSim bench; update interface documentation.
- [x] If RTL changes, run full instrument OOC synthesis; otherwise verify the
  matching existing synthesis checkpoint and inputs. Archive results and pause.

Not this stage: PDW/legacy CSR, AUX producer, FIR reload lifecycle, board PS/DDR/
DMA/RFDC wrapper, BSP/ELF, physical timing closure, BIT/XSA or board testing.
