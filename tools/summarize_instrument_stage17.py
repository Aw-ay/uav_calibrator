from pathlib import Path
import hashlib,json,re
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'reports/instrument_stage17'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
log=(ROOT/'reports/instrument_stage17_synth.log').read_text(errors='replace')
assert 'INSTRUMENT_STAGE17_SYNTH_COMPLETE\n# close_project' in log and not re.search(r'^ERROR:',log,re.M)
assert 'BLACKBOX_COUNT=0' in (out/'configuration.txt').read_text()
inputs=json.loads((out/'source_inputs.json').read_text())
assert all(sha(ROOT/p)==h for p,h in inputs.items()),'Synthesis inputs changed'
reg=json.loads((out/'regression_latest.json').read_text())
assert reg['status']=='PASS' and all(r['exit_code']==0 for r in reg['results'])
ps=json.loads((out/'ps_common_a53_build.json').read_text())
assert ps['status']=='PASS' and all(sha(ROOT/p)==h for p,h in ps['hashes'].items())
for name,marker in [('core','PASS UNIFIED_EVENT actual PDW'),('waveform','PASS TX_LIFECYCLE_CORE seven actual DDS/AWG tasks')]:
    text=(out/f'xsim_{name}.log').read_text(errors='replace')
    assert marker in text and 'XSIM_RUN_FINISHED tb_' in text and not re.search(r'^ERROR:|^Fatal:',text,re.M)
assert 'PROJECT_UPDATED_2025_2\n# exit' in (out/'project_update.log').read_text(errors='replace')
assert 'DIGITAL_PROJECT_REOPEN_OK VERSION=2025.2' in (out/'project_verify.log').read_text(errors='replace')
t=(out/'timing_synth.rpt').read_text();v=t.split('WNS(ns)',1)[1].splitlines()[2].split()
cdc={s:0 for s in ('critical','warning','info')}
for severity,count in re.findall(r'^CDC-\d+\s+(Critical|Warning|Info)\s+(\d+)\s',(out/'cdc.rpt').read_text(),re.M):cdc[severity.lower()]+=int(count)
def cdc_paths(path):
    result=set();source_clock=destination_clock=''
    for line in path.read_text().splitlines():
        if line.startswith('Source Clock:'):source_clock=line.split(':',1)[1].strip()
        elif line.startswith('Destination Clock:'):destination_clock=line.split(':',1)[1].strip()
        elif re.match(r'^\s*\d+\s+CDC-',line):
            cells=line.split();result.add((source_clock,destination_clock,cells[1],cells[2],cells[-2],cells[-1]))
    return result
old_paths=cdc_paths(ROOT/'reports/instrument_stage14/cdc.rpt');new_paths=cdc_paths(out/'cdc.rpt')
comparison=dict(old_count=len(old_paths),new_count=len(new_paths),added=sorted(new_paths-old_paths),removed=sorted(old_paths-new_paths))
(out/'cdc_comparison.json').write_text(json.dumps(comparison,indent=2))
assert 'PASS TX_LIFECYCLE_CORE' in (out/'unbound_sink.log').read_text()
u=(out/'utilization.rpt').read_text()
def used(label):return float(re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',u)[1])
evidence=list(out.glob('*.rpt'))+list(out.glob('*.log'))+list(out.glob('*.json'))+[out/'synth.dcp',ROOT/'reports/instrument_stage17_synth.log']
report=dict(stage=17,utc=datetime.now(timezone.utc).isoformat(),top='calibrator_instrument_core',vivado='2025.2',
    status='DIGITAL_INTEGRATION_COMPLETE_BOARD_PENDING' if min(float(v[0]),float(v[4]),float(v[8]))>=0 and cdc['critical']==0 else 'SYNTHESIS_COMPLETE_TIMING_OR_CDC_OPEN',
    wns_ns=float(v[0]),whs_ns=float(v[4]),wpws_ns=float(v[8]),setup_failing_endpoints=int(v[2]),hold_failing_endpoints=int(v[6]),pulse_failing_endpoints=int(v[10]),
    cdc=cdc,resources=dict(lut=used('CLB LUTs*'),ff=used('CLB Registers'),bram_tile=used('Block RAM Tile'),dsp=used('DSPs')),
    check_timing={k:int(n) for k,n in re.findall(r'checking (\w+) \((\d+)\)',t)},cdc_paths_added=len(comparison['added']),cdc_paths_removed=len(comparison['removed']),unbound_sink_test_pass=True,full_regression_pass=len(reg['results']),xsim_pass=2,a53_c_sources=12,
    board_timing_accepted=False,input_sha256=inputs,evidence_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in evidence})
(ROOT/'reports/stage17_tx_lifecycle_integration.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if not k.endswith('sha256')},indent=2))
