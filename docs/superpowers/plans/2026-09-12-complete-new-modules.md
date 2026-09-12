# Complete new calibrator modules implementation plan

> For agentic workers: execute task-by-task using the executing-plans workflow; independent RF control, waveform and calibration units are delegated under dispatching-parallel-agents. User authorizes continuation without approval checkpoints.

**Goal:** Finish v0.5 logical PL/PS implementation, integration and repeatable verification on feature/complete-new-modules, preserving explicit physical binding and hardware acceptance boundaries.

**Architecture:** Keep 125 MHz RF processing and 200 MHz memory domain, sixteen independent RAW banks, four-range upload arbitration and immutable per-pulse identities. Logical RF state, waveform/calibration and physical board contracts remain separate. Existing verified submodules are reused rather than counted again under aliases in the design catalog.

- [x] Initialize local repository, preserve existing implementation as main baseline 78fd4a0, create feature/complete-new-modules.
- [ ] RF control: normalized interlock feedback, configurable turnaround/recovery, AUX switch/settling; tests for faults and unbound state. Files rtl/control/{rf_safety_interlock,aux_source_controller}.sv and dedicated contract/TBs.
- [ ] Waveforms: 48-bit DDS, burst/chirp timing, AWG inactive-bank atomic load, boundary source mux; real sample reference tests. Files rtl/source/*.sv.
- [ ] Calibration: convergent rounding/saturation, complex RX/TX correction, 2x2 target and programmable fractional delay with explicit numeric/quality evidence. Files rtl/arithmetic/*.sv.
- [ ] Root control/data additions: producer ownership tracking, event queue/PDW, replay task queue and legality validation; prove stale/duplicate rejection and reset drainage. Files rtl/control/event_mailbox.sv, rtl/replay/*, rtl/capture/* as required.
- [ ] Integrated digital top: connect actual qualification/upload/reset to producer controls, calibrated TX source and safety mute. Add real end-to-end TB and explicit ABI header construction; keep physical top separate until bindings exist.
- [ ] PS support: portable control/config/calibration/descriptor validation and transport hooks, actual host/A53 builds; board BSP drivers only with supported platform evidence.
- [ ] Run all software/RTL suites; run new XSim cases under Vivado 2025.2. Review failures before fixes; preserve exact commands/logs.
- [ ] Synthesize/place/route current integrated digital hierarchy with unchanged clocks and truthful CDC constraints. Resolve violations without exceptions that hide real paths. Track clock/pin binding exclusions explicitly.
- [ ] Update original Vivado project, status matrix with actual implementation aliases and evidence, manifest, and local commits. Retain explicit NOT_RUN for physical RF and board tests.

Each implementation batch: inspect source contract; add independent failing test; implement; run focused verification; inspect result; integrate only verified changes; checkpoint commit. No new global contract field silently gains hardware capability status. No automatic Git push, flash programming or guessed board bindings.

## Requested pause

2026-09-12: User requests pause after synthesis and a branch progress report. Stop further development after current synthesis/evidence capture. Functional modules and capture/replay/transmit subsystems are implemented; unified platform integration and complete-system timing remain open. See reports/branch-development.md.
