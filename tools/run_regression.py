"""Run the real software/RTL suites and save exact commands and exit status."""
from pathlib import Path
import json
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
commands = [
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_contracts.py', '-v'],
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_frame_codec.py', '-v'],
] + [[sys.executable, 'tests/' + test] for test in (
    'test_fir_rtl.py', 'test_control_rtl.py', 'test_capture_rtl.py',
    'test_record_rtl.py', 'test_eight_channel_rtl.py',
    'test_axis_fifo_rtl.py', 'test_record_arbiter_rtl.py',
    'test_record_bridge_rtl.py', 'test_record_groups_rtl.py',
    'test_ps_receive_core.py', 'test_pulse_detector_rtl.py',
    'test_native_overload_rtl.py', 'test_replay_reader_rtl.py',
    'test_capture_record_system.py', 'test_detector_scoreboard.py', 'test_range_statistics.py', 'test_range_qualification.py', 'test_noise_snapshot.py', 'test_range_linearity.py', 'test_pulse_context_join.py', 'test_pulse_context_pool.py', 'test_pulse_qualification_engine.py', 'test_qualification_bank_commit.py', 'test_qualification_publish_bridge.py', 'test_qualified_record_upload.py', 'test_qualified_reset_drain.py', 'test_event_mailbox.py', 'test_capture_pdw.py', 'test_rf_control.py', 'test_waveform_sources.py', 'test_calibration_dsp.py', 'test_fractional_delay_profile.py', 'test_replay_control.py', 'test_tx_processing_chain.py', 'test_tx_tail_status.py', 'test_channel_monitor.py', 'test_awg_load_cdc.py', 'test_ps_control_extensions.py', 'test_capture_statistics_reader.py', 'test_calibrator_capture_pipeline.py', 'test_pdw_mailbox_integration.py', 'test_frame_header_builder.py', 'test_coeff_reload.py', 'test_capture_admission_bridge.py', 'test_capture_producer_tracker.py', 'test_calibrator_capture_system.py', 'test_capture_tracker_error_drain.py', 'test_generated_tx_sources.py', 'test_replay_processing_chain.py', 'test_calibrator_transmit_system.py', 'test_replay_task_dispatcher.py', 'test_calibrator_replay_system.py', 'test_capture_replay_binding.py', 'test_calibrator_dataplane_system.py', 'test_command_gateway.py', 'test_receive_frontend.py', 'test_receive_event_producer.py', 'test_command_control.py', 'test_calibrator_instrument_core.py', 'test_waveform_control.py', 'test_instrument_waveform_commands.py', 'test_qualified_pdw_queue.py', 'test_pdw_control.py', 'test_fault_event_contract.py', 'test_fault_event_codec.py', 'test_unified_event_reader.py', 'test_unified_event_axi.py', 'test_event_priority_arbiter.py', 'test_fault_event_path.py', 'test_fault_event_retainer.py', 'test_rf_fault_queue.py', 'test_rf_fault_control.py', 'test_source_event_queue.py', 'test_source_event_control.py')]
results = []
for command in commands:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    results.append(dict(command=command, exit_code=result.returncode,
                        stdout=result.stdout, stderr=result.stderr))
    print(('PASS' if result.returncode == 0 else 'FAIL') + ': ' + ' '.join(command), flush=True)
    if result.returncode:
        print(result.stdout + result.stderr)
report = dict(utc=datetime.now(timezone.utc).isoformat(),
              status='PASS' if all(r['exit_code'] == 0 for r in results) else 'FAIL',
              scope='Software/RTL simulation only; not board or complete-system acceptance', results=results)
(ROOT/'reports/regression_latest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
sys.exit(0 if report['status'] == 'PASS' else 1)
