"""Run selected self-checking SV benches in real Vivado 2025.2 XSim."""
from pathlib import Path
import json
import subprocess
import runpy
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
VIVADO = Path('C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat')
CASES = {
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
    'tb_control': 'PASS control AXI CDC snapshot faults reset',
}
results = []
runpy.run_path(str(ROOT/'tests/test_qualified_record_upload.py'))['vectors']()
for top, marker in CASES.items():
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
    print(top + ': ' + results[-1]['status'], flush=True)
report = dict(utc=datetime.now(timezone.utc).isoformat(), tool='Vivado 2025.2 XSim',
              scope='Selected digital functional benches; no analog RF or timing sign-off', results=results)
(ROOT / 'reports/functional_xsim.json').write_text(json.dumps(report, indent=2))
raise SystemExit(0 if all(r['status'] == 'PASS' for r in results) else 1)
