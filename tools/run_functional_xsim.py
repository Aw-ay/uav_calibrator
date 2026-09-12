"""Run selected self-checking SV benches in real Vivado 2025.2 XSim."""
from pathlib import Path
import json
import subprocess
import runpy
import sys
import hashlib
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
VIVADO = Path('C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat')
CASES = {
    'tb_instrument_waveform_commands': 'PASS instrument waveform commands',
    'tb_command_gateway': 'PASS command gateway',
    'tb_receive_frontend': 'PASS receive frontend',
    'tb_receive_event_producer': 'PASS receive event producer',
    'tb_calibrator_instrument_core': 'PASS instrument core',
    'tb_replay_processing_chain': 'PASS replay processing chain',
    'tb_calibrator_capture_system': 'PASS complete capture system',
    'tb_capture_producer_tracker': 'PASS capture producer tracker',
    'tb_generated_tx_sources': 'PASS generated DDS chirp GSC AWG async bank stop drain',
    'tb_awg_load_cdc': 'PASS AWG asynchronous load CRC commit reset',
    'tb_channel_epoch_aligner': 'PASS channel epoch isolation',
    'tb_tx_reference_analyzer': 'PASS TX reference measured statistics',
    'tb_pdw_mailbox_integration': 'PASS PDW mailbox integration: full queue retains event, exact delivery, no false drop',
    'tb_coeff_reload': 'PASS coefficient CRC pin reload config apply error reset',
    'tb_calibrator_capture_pipeline': 'PASS integrated capture pipeline',
    'tb_capture_statistics_reader': 'PASS capture statistics reader',
    'tb_event_mailbox': 'PASS event mailbox',
    'tb_capture_pdw_writer': 'PASS capture PDW',
    'tb_rf_control': 'PASS RF control',
    'tb_replay_control': 'PASS replay control',
    'tb_waveform_sources': 'PASS waveform',
    'tb_awg_reader': 'PASS AWG',
    'tb_tx_processing_chain': 'PASS TX processing chain',
    'tb_capture_reset_coordinator': 'PASS capture reset coordinator',
    'tb_qualified_reset_drain': 'PASS qualified reset drain',
    'tb_qualification_record_source': 'PASS qualification record source',
    'tb_qualified_record_upload': 'PASS qualified record upload',
    'tb_qualification_publish_bridge': 'PASS qualification publish bridge',
    'tb_qualification_bank_commit': 'PASS qualification bank commit',
    'tb_pulse_qualification_engine': 'PASS qualification engine',
    'tb_pulse_context_pool': 'PASS pulse context pool',
    'tb_pulse_context_join': 'PASS pulse context join',
    'tb_range_linearity': 'PASS range linearity',
    'tb_noise_snapshot': 'PASS noise snapshot',
    'tb_range_qualification': 'PASS range qualification',
    'tb_range_statistics': 'PASS range statistics',
    'tb_detector_scoreboard': 'PASS detector scoreboard',
    'tb_pulse_detector': 'PASS pulse_detector',
    'tb_frozen_replay_reader': 'PASS frozen replay reader',
    'tb_capture_replay_binding': 'PASS capture replay binding',
    'tb_calibrator_dataplane_cancel': 'PASS integrated dataplane soft reset',
    'tb_calibrator_dataplane_system': 'PASS integrated dataplane',
    'tb_control': 'PASS control AXI CDC snapshot faults reset',
}
results = []
runpy.run_path(str(ROOT/'tests/test_qualified_record_upload.py'))['vectors']()
runpy.run_path(str(ROOT/'tests/test_calibrator_capture_system.py'))['vectors']()
selected = {top: CASES[top] for top in sys.argv[1:]} if len(sys.argv) > 1 else CASES
for top, marker in selected.items():
    log = ROOT / 'reports' / f'xsim_functional_{top}.log'
    command = [str(VIVADO), '-mode', 'batch', '-nojournal', '-log', str(log),
               '-source', str(ROOT / 'hw/tcl/run_functional_tb.tcl'), '-tclargs', top]
    try:
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=600)
        output = run.stdout + run.stderr
        (ROOT / 'reports' / f'xsim_functional_{top}_console.log').write_text(output)
        passed = run.returncode == 0 and marker in output and 'Fatal:' not in output and 'FATAL' not in output
        results.append(dict(top=top, status='PASS' if passed else 'FAIL', exit_code=run.returncode, log=str(log)))
    except (OSError, subprocess.TimeoutExpired) as error:
        results.append(dict(top=top, status='TOOL_ERROR', error=str(error)))
    results[-1]['source_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (list((ROOT/'rtl').rglob('*.sv'))+list((ROOT/'tb').rglob('*.sv')))}
    (ROOT/'reports'/f'xsim_result_{top}.json').write_text(json.dumps(results[-1],indent=2))
    print(top + ': ' + results[-1]['status'], flush=True)
report = dict(utc=datetime.now(timezone.utc).isoformat(), tool='Vivado 2025.2 XSim',
              scope='Selected digital functional benches; no analog RF or timing sign-off', results=results)
(ROOT / ('reports/functional_xsim_selected.json' if len(sys.argv)>1 else 'reports/functional_xsim.json')).write_text(json.dumps(report, indent=2))
raise SystemExit(0 if all(r['status'] == 'PASS' for r in results) else 1)
