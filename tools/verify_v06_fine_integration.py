"""Collect current Fine delivery evidence; never equate synthesis with board closure.

Run after tools/run_regression.py, Fine XSim, original-project verification and
hw/tcl/instrument_v06_fine.tcl. This collector does not launch another synthesis.
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

snapshot = json.loads(read('reports/v06_fine_final_inputs.json'))
for path, digest in snapshot['sha256'].items():
    assert sha(ROOT/path)==digest, 'Synthesis input changed: '+path
validation = json.loads(read('reports/v06_fine_final_validation_inputs.json'))
for path,digest in validation['sha256'].items():
    assert sha(ROOT/path)==digest, 'Validation input changed: '+path
protected = json.loads(read('reports/v06_external_baseline.json'))
for path, digest in protected.items():
    assert sha(ROOT/path)==digest, 'Protected file changed: '+path
regression = json.loads(read('reports/regression_latest.json'))
assert regression['status']=='PASS' and len(regression['results'])==131
assert all(r['exit_code']==0 for r in regression['results'])
assert all('PASS' in r['stdout'] or re.search(r'^OK$',r['stderr'],re.M) for r in regression['results'] if any('test_fine_' in a for a in r['command']))
marker('reports/v06_fine_final_xsim.log','PASS Fine complete single-pass engine LATENCY=1 jobs=31')
marker('reports/v06_fine_project_verify.log','DIGITAL_PROJECT_REOPEN_OK')
marker('reports/instrument_v06_fine_final_synth.log','INSTRUMENT_V06_FINE_SYNTH_COMPLETE')
for n in [256,16384]:
    marker(f'reports/v06_fine_bank_service_{n}.log','rejected jobs count losses and return leases')
marker('reports/v06_fine_result_transport.log','full simultaneous POP/PUSH')
for latency in [1,2,3]:
    marker(f'reports/v06_fine_engine_l{latency}.log','jobs=31')
module = timing('reports/v06_modules/fine_engine_fast')
assert module['resources']['DSPs']<=48
service = timing('reports/v06_modules/fine_service')
marker('reports/v06_fine_service_synth.log','V06_FINE_SERVICE_SYNTH_COMPLETE')
assert not re.search(r'^CDC-\d+\s+Critical',read('reports/v06_modules/fine_service/cdc.rpt'),re.M)
transport = timing('reports/v06_modules/fine_transport')
marker('reports/v06_fine_transport_synth.log','V06_FINE_TRANSPORT_SYNTH_COMPLETE')
fix_names={'test_fine_result_transport.py','test_fine_control.py','test_calibrator_instrument_core.py','test_instrument_aux_commands.py','test_instrument_waveform_commands.py','test_fine_replay_isolation.py'}
fix_checks = [r for r in regression['results'] if any('tests/'+n in r['command'] for n in fix_names)]
assert len(fix_checks)==6 and all(r['exit_code']==0 for r in fix_checks)
assert 'PASS independent three-range Fine PDW decode' in next(r for r in fix_checks if 'tests/test_calibrator_instrument_core.py' in r['command'])['stdout']
core = timing('reports/instrument_v06_fine')
cdc = dict(Critical=0, Warning=0, Info=0)
for severity, count in re.findall(r'^CDC-\d+\s+(Critical|Warning|Info)\s+(\d+)', read('reports/instrument_v06_fine/cdc.rpt'), re.M):
    cdc[severity] += int(count)
assert cdc['Critical']==0, cdc
constraints = {k:int(v) for k,v in re.findall(r'checking (\w+) \((\d+)\)',read('reports/instrument_v06_fine/check_timing.rpt'))}
for key in ['no_clock','unconstrained_internal_endpoints','loops','latch_loops']:
    assert constraints.get(key)==0, (key,constraints.get(key))
f7 = marker('reports/v06_fine_sustained.log','pulses=12 ranges=36 samples_per_range=16384')
cycles = int(re.search(r'worst_three_range_cycles=(\d+)',f7)[1])
assert cycles<60606
cbuild = json.loads(read('reports/ps_common_a53_build.json'))
assert cbuild['status']=='PASS'
assert 'sw/common/fine_control.c' in cbuild['hashes']
marker('reports/v06_fine_replay_isolation.log','identical actual_start_gsc and 93 RAW IQ/GSC beats')
core_result = next(r for r in regression['results'] if 'tests/test_calibrator_instrument_core.py' in r['command'])
assert 'PASS independent three-range Fine PDW decode' in core_result['stdout']
files = set(ROOT.glob('rtl/**/*.sv')) | set(ROOT.glob('contracts/*.json'))
files |= set(ROOT.glob('tests/test_fine*.py')) | set(ROOT.glob('tb/unit/tb_fine*.sv'))
files |= {ROOT/p for p in ['hw/tcl/instrument_v06_fine.tcl','hw/tcl/v06_fine_engine_fast.tcl',
    'hw/tcl/v06_fine_service.tcl','hw/tcl/v06_fine_transport.tcl','hw/tcl/v06_fine_engine_tb.tcl',
    'hw/tcl/update_project_2025_2.tcl','hw/tcl/verify_project.tcl','tools/verify_v06_fine_integration.py','tools/snapshot_v06_fine_inputs.py','tools/run_regression.py',
    'tools/build_ps_common.py','sw/common/fine_control.c','sw/common/include/fine_control.h',
    'tests/test_calibrator_instrument_core.py','tb/system/tb_calibrator_instrument_core.sv',
    'tests/test_fine_sustained.py','tb/system/tb_fine_sustained.sv','docs/v06_fine_integration.md',
    'build/calibrator_zu27dr/calibrator_zu27dr.xpr','reports/regression_latest.json',
    'reports/v06_fine_final_inputs.json','reports/v06_fine_final_validation_inputs.json','reports/ps_common_a53_build.json',
    'reports/v06_fine_final_xsim.log','reports/v06_fine_project_verify.log','reports/instrument_v06_fine_final_synth.log']}
for pattern in ['reports/instrument_v06_fine/*.rpt','reports/v06_modules/fine_engine_fast/*.rpt','reports/v06_modules/fine_transport/*.rpt','reports/v06_modules/fine_service/*.rpt','reports/v06_fine_*.log']:
    files |= set(ROOT.glob(pattern))
report = dict(status='PASS_FINE_DIGITAL_SYNTH_ESTIMATE_ONLY', utc=datetime.now(timezone.utc).isoformat(),
    scope='Active instrument Fine chain; current working tree includes protected external RTL. No board/post-route acceptance; old FD63 exit remains separate.',
    regression_suites=len(regression['results']), registered_suites=131, additional_checks='Service rejection at256/16384, queue concurrent full pop/push,31 engine vectors at latency1/2/3, paired actual-core replay isolation',
    module=module, service=service, transport=transport, core=core, post_transport_fix_checks=6, cdc_unwaived=cdc, constraints=constraints,
    f7=dict(pulses=12,ranges=36,samples_per_range=16384,period_cycles=60606,
            worst_three_range_cycles=cycles,worst_us=cycles/200,
            scope='Defined analytic waveform, timely selected RAW return; not arbitrary ringing or unlimited DMA stalls'),
    protected_sha256=protected, hashes={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(files)})
(ROOT/'reports/v06_fine_delivery.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['hashes','protected_sha256']},indent=2))
