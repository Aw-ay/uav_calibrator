from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'reports/module_stage22'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((out/'inputs.json').read_text())
assert all(sha(ROOT/p)==h for p,h in inputs.items()),'Inputs changed after validation'
syn=(ROOT/'reports/stage22_aux_synth_final.log').read_text(errors='replace')
sim=(ROOT/'reports/stage22_aux_xsim_final.log').read_text(errors='replace')
assert 'STAGE22_MODULE_SYNTH_COMPLETE\n# close_project' in syn and 'Exiting Vivado' in syn
assert 'PASS AUX_RECEIVE_GUARD' in sim and 'STAGE22_XSIM_FINISHED tb_aux_receive_guard;' in sim and 'Exiting Vivado' in sim
assert not re.search(r'^ERROR:|^FATAL:',syn+'\n'+sim,re.M)
reg=json.loads((out/'related_regression.json').read_text());assert len(reg)==4 and all(x['exit_code']==0 for x in reg)
t=(out/'timing_synth.rpt').read_text();v=t.split('WNS(ns)',1)[1].splitlines()[2].split()
u=(out/'utilization.rpt').read_text()
def used(label):return float(re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',u)[1])
evidence=list(out.glob('*.rpt'))+[out/'synth.dcp',out/'related_regression.json',ROOT/'reports/stage22_aux_synth_final.log',ROOT/'reports/stage22_aux_xsim_final.log']
d=dict(stage=22,top='aux_receive_guard',status='STANDALONE_VALIDATED_CORE_INTEGRATION_PENDING',
       related_runners_pass=4,xsim_pass=1,full_core_synthesis_run=False,board_timing_accepted=False,
       wns_ns=float(v[0]),whs_ns=float(v[4]),wpws_ns=float(v[8]),setup_failing_endpoints=int(v[2]),hold_failing_endpoints=int(v[6]),pulse_failing_endpoints=int(v[10]),
       resources=dict(lut=used('CLB LUTs*'),ff=used('CLB Registers'),bram_tile=used('Block RAM Tile'),dsp=used('DSPs')),
       input_sha256=inputs,evidence_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in evidence})
assert min(d['wns_ns'],d['whs_ns'],d['wpws_ns'])>=0 and sum(d[k] for k in ['setup_failing_endpoints','hold_failing_endpoints','pulse_failing_endpoints'])==0
(ROOT/'reports/stage22_aux_receive_guard.json').write_text(json.dumps(d,indent=2))
print(json.dumps({k:v for k,v in d.items() if not k.endswith('sha256')},indent=2))
