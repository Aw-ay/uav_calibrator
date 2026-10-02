"""Run Fine numerical/kernel checks; deliberately does not claim full Fine integration."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
checks=[]
for name in ['test_fine_reference.py','test_fine_fixed.py','test_fine_edge_fixed.py','test_fine_spectral_fixed.py','test_fine_cordic.py']:
 command=[sys.executable,'-X','utf8','tests/'+name]
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
 checks.append(dict(command=command,exit_code=r.returncode,stdout=r.stdout,stderr=r.stderr))
 print(('PASS' if r.returncode==0 else 'FAIL')+': '+name)
 assert r.returncode==0,r.stdout+r.stderr
out=ROOT/'reports/v06_modules/fine_cordic'
t=(out/'timing_synth.rpt').read_text()
m=re.search(r'WNS\(ns\).*?\n.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)',t)
assert m and all(int(m[i])==0 for i in [3,7,11]) and all(float(m[i])>=0 for i in [1,5,9])
for path,digest in json.loads((ROOT/'reports/v06_external_baseline.json').read_text()).items():
 assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
paths=['contracts/fine_numeric.json','tools/fine_reference.py','tools/fine_fixed.py','rtl/fine/fine_cordic.sv','tb/unit/tb_fine_cordic.sv','hw/tcl/v06_fine_cordic.tcl','tools/verify_v06_fine_numeric.py']+[c['command'][-1] for c in checks]
paths += ['reports/v06_modules/fine_cordic/timing_synth.rpt','reports/v06_modules/fine_cordic/utilization.rpt']
report=dict(status='PASS',utc=datetime.now(timezone.utc).isoformat(),scope='Batch mathematical/integer reference plus one standalone CORDIC kernel; no full Fine engine, no new whole-core synthesis',checks=checks,timing_ns=dict(WNS=float(m[1]),WHS=float(m[5]),WPWS=float(m[9])),hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths})
(ROOT/'reports/v06_fine_numeric_delivery.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS Fine numeric stage: standalone kernel 200MHz, not full engine timing')
