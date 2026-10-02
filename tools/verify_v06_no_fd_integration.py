"""Collect no-FD integration evidence; never equate synthesis with board closure.

Run after tools/run_regression.py, no-FD XSim, original-project verification and
hw/tcl/instrument_v06_no_fd.tcl. This collector does not launch another synthesis.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re
ROOT = Path(__file__).resolve().parents[1]

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(name):
    return (ROOT/name).read_text(encoding='utf-8', errors='replace')

def marker(name, expected):
    text = read(name)
    assert expected in text and not re.search(r'^(ERROR:|FATAL)', text, re.M), name
    return text

def timing(folder):
    text = read(folder+'/timing_synth.rpt')
    pat = r'WNS\(ns\).*?\n[^\n]*\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)'
    m = re.search(pat, text)
    assert m, folder
    out = dict(wns_ns=float(m[1]), whs_ns=float(m[5]), wpws_ns=float(m[9]),
               setup_failing=int(m[3]), hold_failing=int(m[7]), pulse_failing=int(m[11]))
    assert all(out[k]>=0 for k in ['wns_ns','whs_ns','wpws_ns']), out
    assert not any(out[k] for k in ['setup_failing','hold_failing','pulse_failing']), out
    resources = {}
    util = read(folder+'/utilization.rpt')
    for key in ['CLB LUTs','CLB Registers','Block RAM Tile','DSPs']:
        match = re.search(r'\| '+re.escape(key)+r'\*?\s*\|\s*([\d.]+)', util)
        assert match, key
        resources[key] = float(match[1])
    out['resources'] = resources
    return out

for name in ['v06_no_fd_inputs.json']:
    snapshot=json.loads(read('reports/'+name))
    for path,digest in snapshot['sha256'].items():
        assert sha(ROOT/path)==digest,'Input changed: '+path
protected=json.loads(read('reports/v06_external_baseline.json'))
for path,digest in protected.items():assert sha(ROOT/path)==digest,'Protected changed: '+path
regression=json.loads(read('reports/v06_no_fd_regression.json'))
assert sha(ROOT/regression['baseline_path'])==regression['baseline_sha256']
for path,h in regression['validation_sha256'].items():assert sha(ROOT/path)==h,path
assert json.loads(read('reports/v06_no_fd_validation_inputs.json'))['sha256']==regression['validation_sha256']
assert regression['status']=='PASS' and len(regression['results'])==133
assert all(r['exit_code']==0 for r in regression['results'])
marker('reports/v06_replay_phase_boundary.log','PASS13 earliest and adjacent scheduling task phase cases')
marker('reports/v06_replay_no_fd_vectors.log','PASS no-FD640 fixed-point vectors')
marker('reports/v06_replay_no_fd_xsim.log','PASS replay processing chain actual RXCAL Target')
marker('reports/v06_no_fd_project_verify.log','DIGITAL_PROJECT_REOPEN_OK')
active_sources=marker('reports/project_2025_2_sources.txt','TOP=calibrator_instrument_core')
for old in ['fractional_delay.sv','fractional_delay_profile.sv','fractional_delay_pipelined.sv','fractional_delay_coeff_rom.sv','frozen_record_reader.sv','record_formatter.sv']:
    assert old not in active_sources,'Retired source active: '+old
marker('reports/v06_replay_no_fd_synth.log','V06_REPLAY_NO_FD_SYNTH_COMPLETE')
marker('reports/instrument_v06_no_fd_synth.log','INSTRUMENT_V06_NO_FD_SYNTH_COMPLETE')
marker('reports/instrument_v06_no_fd_synth.log','NO_FD_ACTIVE_CELLS=0')
module=timing('reports/v06_modules/replay_no_fd')
marker('reports/v06_replay_system_no_fd_synth.log','V06_REPLAY_SYSTEM_NO_FD_SYNTH_COMPLETE')
system=timing('reports/v06_modules/replay_system_no_fd')
core=timing('reports/instrument_v06_no_fd')
previous=json.loads(read('reports/fine_completed_2ca0959/v06_fine_delivery.json'))['core']['resources']
resource_delta={k:core['resources'][k]-v for k,v in previous.items()}
cdc=dict(Critical=0,Warning=0,Info=0)
for severity,count in re.findall(r'^CDC-\d+\s+(Critical|Warning|Info)\s+(\d+)',read('reports/instrument_v06_no_fd/cdc.rpt'),re.M):cdc[severity]+=int(count)
assert cdc['Critical']==0,cdc
constraints={k:int(v) for k,v in re.findall(r'checking (\w+) \((\d+)\)',read('reports/instrument_v06_no_fd/check_timing.rpt'))}
for k in ['no_clock','unconstrained_internal_endpoints','loops','latch_loops']:assert constraints.get(k)==0,(k,constraints.get(k))
marker('reports/v06_fine_replay_isolation.log','identical actual_start_gsc and 93 RAW IQ/GSC beats')
assert 'PASS independent three-range Fine PDW decode' in next(r for r in regression['results'] if 'tests/test_calibrator_instrument_core.py' in r['command'])['stdout']
files=set()
for pattern in ['rtl/**/*.sv','contracts/*.json','tests/*.py','tb/**/*.sv','hw/tcl/*no_fd*.tcl','reports/instrument_v06_no_fd/*.rpt','reports/v06_modules/replay_no_fd/*.rpt','reports/v06_modules/replay_system_no_fd/*.rpt','reports/*no_fd*.log']:
    files.update(ROOT.glob(pattern))
files.update(ROOT/p for p in ['tools/verify_v06_no_fd_integration.py','tools/snapshot_v06_no_fd_inputs.py','tools/run_regression.py','hw/tcl/update_project_2025_2.tcl','hw/tcl/verify_project.tcl','docs/v06_replay_no_fd.md','reports/project_2025_2_sources.txt','reports/fine_completed_2ca0959/v06_fine_delivery.json','reports/regression_latest.json','reports/v06_no_fd_regression.json','tools/retry_v06_no_fd_regression.py','reports/v06_no_fd_inputs.json','reports/v06_no_fd_validation_inputs.json','build/calibrator_zu27dr/calibrator_zu27dr.xpr'])
report=dict(status='PASS_NO_FD_DIGITAL_SYNTH_ESTIMATE_ONLY',utc=datetime.now(timezone.utc).isoformat(),regression_suites=133,retried_suites=len(regression['attempts']),module=module,system=system,core=core,resource_delta_vs_fine_2ca0959=resource_delta,cdc_unwaived=cdc,constraints=constraints,raw_to_target_gsc_ticks=12,accepted_input_to_output_rf_intervals=2,fd_flush_samples=0,active_fd_cells=0,protected_sha256=protected,scope='Current tree includes protected external RTL. No physical board/post-route acceptance.',hashes={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(files)})
(ROOT/'reports/v06_no_fd_delivery.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['hashes','protected_sha256']},indent=2))
