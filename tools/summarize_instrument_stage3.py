"""Summarize completed tool evidence without treating synthesis as board sign-off."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'reports/instrument_stage3'
log=(ROOT/'reports/instrument_stage3_synth.log').read_text(errors='replace')
assert 'INSTRUMENT_STAGE3_SYNTH_COMPLETE' in log and not re.search(r'^ERROR:',log,re.M)
configuration=(out/'configuration.txt').read_text()
assert 'TOP=calibrator_instrument_core BLACKBOX_COUNT=0' in configuration
timing=(out/'timing_synth.rpt').read_text()
assert 'calibrator_instrument_core' in timing and 'Synthesized' in timing
line=timing.split('WNS(ns)',1)[1].splitlines()[2].split()
wns,tns,whs,ths=map(float,[line[0],line[1],line[4],line[5]])
cdc={s.lower():0 for s in ['Critical','Warning','Info']}
for severity,count in re.findall(r'^CDC-\d+\s+(Critical|Warning|Info)\s+(\d+)\s', (out/'cdc.rpt').read_text(),re.M):cdc[severity.lower()]+=int(count)
util=(out/'utilization.rpt').read_text()
def used(label):return float(re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',util)[1])
checks={k:int(v) for k,v in re.findall(r'checking (\w+) \((\d+)\)',timing)}
regression=json.loads((ROOT/'reports/regression_latest.json').read_text())
assert regression['status']=='PASS'
xsims=['tb_command_gateway','tb_receive_frontend','tb_receive_event_producer','tb_calibrator_instrument_core']
assert all(json.loads((ROOT/f'reports/xsim_result_{name}.json').read_text())['status']=='PASS' for name in xsims)
inputs=json.loads((out/'source_inputs.json').read_text())
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in inputs.items()),'Synthesis inputs changed'
evidence=list(out.glob('*.rpt'))+[out/'synth.dcp',ROOT/'reports/regression_latest.json']
report=dict(utc=datetime.now(timezone.utc).isoformat(),branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
 top='calibrator_instrument_core',vivado='2025.2',status='SYNTHESIS_COMPLETE_TIMING_OPEN' if wns<0 or whs<0 or cdc['critical'] else 'DIGITAL_STAGE3_COMPLETE_BOARD_PENDING',
 wns_ns=wns,tns_ns=tns,setup_failing_endpoints=int(line[2]),whs_ns=whs,ths_ns=ths,hold_failing_endpoints=int(line[6]),
 blackboxes=0,cdc=cdc,check_timing=checks,resources=dict(lut=used('CLB LUTs*'),ff=used('CLB Registers'),bram_tile=used('Block RAM Tile'),dsp=used('DSPs')),
 full_regression_pass=len(regression['results']),new_xsim_pass=len(xsims),board_top_complete=False,routed_timing_validated=False,
 input_sha256=inputs,evidence_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in evidence})
(ROOT/'reports/stage3_control_ingress.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if not k.endswith('sha256')},indent=2))
