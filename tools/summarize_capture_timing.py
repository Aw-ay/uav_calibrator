"""Summarize actual routed diagnostic reports; never infer missing results."""
from pathlib import Path
import hashlib,json,re
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
base=ROOT/'reports/new_capture_registered_timing'
rows=[]
for name in ('pulse_range_statistics','noise_snapshot','noise_window_energy','range_qualification'):
    path=base/name/'timing.rpt'
    if not path.exists():
        rows.append(dict(module=name,status='NOT_RUN'));continue
    text=path.read_text()
    pattern=r'^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)'
    m=re.search(pattern,text,re.M)
    if not m: raise RuntimeError('No timing summary in '+str(path))
    wns,tns,setup_bad,setup_total,whs,ths,hold_bad,hold_total=m.groups()
    rows.append(dict(module=name,status='MET_DIAGNOSTIC_BUDGET' if float(wns)>=0 and float(whs)>=0 else 'VIOLATED',
        wns_ns=float(wns),tns_ns=float(tns),setup_failing_endpoints=int(setup_bad),
        whs_ns=float(whs),ths_ns=float(ths),hold_failing_endpoints=int(hold_bad),
        report=path.relative_to(ROOT).as_posix()))
files=[p for p in base.rglob('*') if p.is_file() and p.suffix in ('.rpt','.dcp')]
report=dict(utc=datetime.now(timezone.utc).isoformat(),clock_mhz=125,period_ns=8,
    scope='OOC routed with real launch/capture registers at every DUT port; fixture external IO unconstrained, core reg-to-reg paths timed at 125 MHz; NOT integrated board timing sign-off',
    modules=rows,sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
(base/'summary.json').write_text(json.dumps(report,indent=2))
print(json.dumps(rows,indent=2))
