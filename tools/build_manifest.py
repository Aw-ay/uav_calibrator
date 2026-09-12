"""Bind checked-in/generated sources and completed tool evidence to SHA256."""
from pathlib import Path
import hashlib
import json
from datetime import datetime, timezone
ROOT=Path(__file__).resolve().parents[1]
files=set()
files.add(ROOT/'reports/qualified_reset_drain_progress.md')
files.add(ROOT/'reports/tb_capture_reset_coordinator_0.log')
files.add(ROOT/'reports/tb_qualified_reset_drain_0.log')
files.add(ROOT/'reports/tb_qualified_reset_drain_1.log')
files.add(ROOT/'reports/qualified_record_upload_progress.md')
files.add(ROOT/'reports/qualified_record_upload.log')
files.add(ROOT/'reports/qualification_record_source.log')
files.update((ROOT/'build/qualified_upload_vectors').glob('*.hex'))
files.add(ROOT/'reports/qualification_publish_bridge_progress.md')
files.add(ROOT/'reports/qualification_publish_bridge.log')
files.add(ROOT/'reports/qualification_bank_commit_progress.md')
files.add(ROOT/'reports/qualification_bank_commit.log')
files.add(ROOT/'reports/pulse_qualification_engine_progress.md')
files.add(ROOT/'reports/pulse_qualification_engine.log')
files.add(ROOT/'reports/pulse_context_pool_progress.md')
files.add(ROOT/'reports/pulse_context_pool.log')
files.add(ROOT/'reports/pulse_context_join_progress.md')
files.add(ROOT/'reports/pulse_context_join.log')
files.add(ROOT/'reports/range_linearity_progress.md')
files.add(ROOT/'reports/range_linearity.log')
files.update(p for p in (ROOT/'reports/new_capture_registered_timing').rglob('*') if p.is_file())
files.add(ROOT/'reports/noise_snapshot_progress.md')
files.add(ROOT/'reports/noise_snapshot.log')
files.add(ROOT/'reports/range_qualification_progress.md')
files.add(ROOT/'reports/range_qualification.log')
files.add(ROOT/'docs/RF逻辑与板级绑定.md')
files.add(ROOT/'reports/range_statistics_progress.md')
files.add(ROOT/'reports/range_statistics.log')
files.add(ROOT/'reports/range_statistics_ooc/synth.dcp')
files.add(ROOT/'reports/range_statistics_ooc/utilization.rpt')
files.update((ROOT/'reports').glob('xsim_functional_*.log'))
for folder in ('rtl','contracts','hw/boards','hw/tcl','hw/coefficients','sw/common','sw/matlab','tests','tb','tools'):
    files.update(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
for name in ('capture_ram_probe','dma_probe','rfdc_probe'):
    files.add(ROOT/f'build/ip_probe_2025_2/calibrator_ip_probe.srcs/sources_1/ip/{name}/{name}.xci')
    files.add(ROOT/f'build/ip_probe_2025_2/calibrator_ip_probe.runs/{name}_synth_1/{name}.dcp')
for direction in ('rx','tx'):
    files.add(ROOT/f'reports/fir_ooc_{direction}/route.dcp')
    files.add(ROOT/f'reports/fir_ooc_{direction}/timing_route.rpt')
for folder, names in {
    'record_fifo_ooc': ('route.dcp','timing.rpt','utilization.rpt'),
    'record_upload_ooc': ('synth.dcp','cdc.rpt','utilization.rpt'),
    'pulse_detector_ooc': ('route.dcp','timing.rpt','timing_interface.rpt','timing_iq_paths.rpt','utilization.rpt'),
    'capture_record_ooc': ('synth.dcp','cdc.rpt','utilization.rpt','configuration.txt'),
    'native_overload_monitor_ooc': ('synth.dcp','utilization.rpt'),
    'frozen_replay_reader_ooc': ('synth.dcp','utilization.rpt'),
}.items():
    for name in names:
        files.add(ROOT/'reports'/folder/name)
for rel in ('AGENTS.md','docs/implementation-progress.md','reports/continuation-ledger.md','reports/continuation_validation.md',
            'reports/review_record_upload.md','reports/review_ps_receive.md','reports/review_pulse_detector.md',
            'reports/platform_candidate_test.txt','reports/platform_candidate_2025_2.md',
            'reports/record_bridge_green.log','reports/verify_project_continuation_2025_2.log',
            'reports/review_capture_record_system.md','reports/review_native_overload.md','reports/review_replay_reader.md',
            'reports/ps_common_a53_build.json','build/ps_common_a53_2025_2/libcalibrator_receive.a',
            'build/ps_common_a53_2025_2/frame_decode.o','build/ps_common_a53_2025_2/dma_slots.o',
            'build/platform_candidate_2025_2/platform_candidate.xpr',
            'build/platform_candidate_2025_2/platform_candidate.srcs/sources_1/bd/platform_candidate/platform_candidate.bd'):
    files.add(ROOT/rel)
for rel in ('docs/TB验证说明.md','reports/detector_scoreboard.json','reports/functional_xsim.json',
            'README.md','reports/board_source_audit.md','reports/digital_core_synth.dcp','reports/digital_core_utilization.rpt',
            'reports/regression_latest.json','reports/xsim_capture_bmg.log',
            'build/calibrator_zu27dr/calibrator_zu27dr.xpr'):
    files.add(ROOT/rel)
# Branch evidence retains focused runs and routed fixtures, including failure history.
files.update(p for p in (ROOT/'reports').glob('*.json') if not p.name.startswith('artifact_manifest'))
files.update((ROOT/'reports').glob('*progress.md'))
files.add(ROOT/'reports/branch-development.md')
for folder in ('calibration_timing','pulse_detector_registered_timing','tx_chain_registered_timing','capture_system_ooc','calibrator_transmit_ooc','generated_tx_sources_ooc','coeff_reload_ooc'):
    files.update(p for p in (ROOT/'reports'/folder).rglob('*') if p.is_file())
for name in ('event_control.o','calibration_table.o'):
    files.add(ROOT/'build/ps_common_a53_2025_2'/name)
missing=[str(p.relative_to(ROOT)) for p in sorted(files) if not p.is_file()]
if missing: raise SystemExit('Missing artifacts: '+', '.join(missing))
report={
 'utc':datetime.now(timezone.utc).isoformat(),
 'status':'PARTIAL_DIGITAL_IMPLEMENTATION_NOT_COMPLETE_SYSTEM',
 'vivado':'2025.2','sw_build':'6299465','part':'xczu27dr-fsve1156-2-i',
 'part_evidence_status':'PROJECT_TARGET_PHYSICAL_SPEED_GRADE_NOT_VERIFIED',
 'full_system_timing':'NOT_RUN','hardware_validation':'NOT_RUN',
 'detector_interface_timing':'REGISTERED_125MHZ_OOC_PASS_WNS_1.599_WHS_0.041_OLD_ZERO_IO_DELAY_DIAGNOSTIC_RETAINED',
 'historical_evidence':{'reports/record_upload_ooc':'Predates added idle_rf output; current upload hierarchy synthesized within capture_record_ooc'},
 'bitstream':'NOT_GENERATED','xsa':'NOT_GENERATED','elf':'NOT_GENERATED',
 'hashes':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
}
(ROOT/'reports/artifact_manifest_2025_2.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(f'Bound {len(files)} source/artifact hashes; full system remains incomplete.')
