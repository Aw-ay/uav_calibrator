"""Retry failed suites after the baseline run ends; preserve every failed attempt."""
from pathlib import Path
import hashlib,json,subprocess
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'reports/v06_no_fd_validation_inputs.json').read_text())
current={path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in manifest['sha256']}
assert current==manifest['sha256'],'Validation inputs changed'
original=ROOT/'reports/regression_latest.json'
source=json.loads(original.read_text())
assert len(source['results'])==133
report=dict(source)
report['baseline_sha256']=hashlib.sha256(original.read_bytes()).hexdigest()
report['baseline_path']='reports/regression_latest.json'
report['validation_sha256']=current
report['changed_test_inputs']=[]
report['attempts']=[];report['results']=[]
for r in source['results']:
    if r['exit_code']:
        p=subprocess.run(r['command'],cwd=ROOT,text=True,capture_output=True)
        retry=dict(command=r['command'],exit_code=p.returncode,stdout=p.stdout,stderr=p.stderr)
        report['attempts'].append(dict(initial=r,retry=retry))
        report['results'].append(retry)
        print(('PASS' if p.returncode==0 else 'FAIL')+': '+' '.join(r['command']),flush=True)
        if p.returncode:print(p.stdout+p.stderr,flush=True)
    else:report['results'].append(r)
report['status']='PASS' if all(r['exit_code']==0 for r in report['results']) else 'FAIL'
report['utc']=datetime.now(timezone.utc).isoformat()
for path,h in current.items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==h,path
(ROOT/'reports/v06_no_fd_regression.json').write_text(json.dumps(report,indent=2)+'\n')
print(report['status'],len(report['results']),'suites; retained',len(report['attempts']),'retries')
raise SystemExit(0 if report['status']=='PASS' else 1)
