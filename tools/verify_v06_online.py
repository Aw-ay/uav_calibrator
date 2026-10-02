"""Verify D05 evidence; does not substitute module timing for whole-core timing."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['v06_external_baseline.json','v06_online_integration_inputs.json']:
 for path,digest in json.loads((ROOT/'reports'/manifest).read_text()).items():
  assert sha(ROOT/path)==digest,('changed input',path)
r=json.loads((ROOT/'reports/v06_online_regression.json').read_text())
assert r['status']=='PASS' and len(r['results'])==108 and all(x['exit_code']==0 for x in r['results'])
a=json.loads((ROOT/'reports/ps_common_a53_build.json').read_text());assert a['status']=='PASS'
for path,digest in a['hashes'].items():assert sha(ROOT/path)==digest,path
logs={'v06_receive_online_xsim.log':'PASS actual detector','v06_online_project_verify.log':'DIGITAL_PROJECT_REOPEN_OK','v06_capture_online_synth.log':'V06_ONLINE_STATISTICS_SYNTH_COMPLETE'}
for name,marker in logs.items():
 text=(ROOT/'reports'/name).read_text(errors='replace')
 assert marker in text and not re.search(r'^(FATAL|ERROR:)',text,re.M),name
out=ROOT/'reports/v06_modules/capture_online_statistics'
t=(out/'timing_synth.rpt').read_text()
m=re.search(r'WNS\(ns\).*?\n.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)',t)
assert m and all(int(m[i])==0 for i in [3,7,11])
assert all(float(m[i])>=0 for i in [1,5,9])
util=(out/'utilization.rpt').read_text();resources={}
for name in ['CLB LUTs*','CLB Registers','Block RAM Tile','DSPs']:
 match=re.search(r'\| '+re.escape(name)+r'\s*\|\s*([\d.]+)',util);assert match,name
 resources[name]=float(match[1])
report={'status':'PASS','scope':'D05 active online qualification, module OOC only; full core not rerun; no board acceptance',
 'regression_count':108,'regression_utc':r['utc'],'module_clock_hz':125000000,
 'timing_ns':{'WNS':float(m[1]),'WHS':float(m[5]),'WPWS':float(m[9])},'resources':resources,
 'top_estimator':'primitive tested; pruned in qualification wrapper until Fine consumer exists',
 'inputs_manifest_sha256':sha(ROOT/'reports/v06_online_integration_inputs.json'),
 'evidence_sha256':{p.relative_to(ROOT).as_posix():sha(p) for p in [out/'timing_synth.rpt',out/'utilization.rpt',ROOT/'reports/v06_online_regression.json',ROOT/'reports/ps_common_a53_build.json']+[ROOT/'reports'/n for n in logs]}}
(ROOT/'reports/v06_online_delivery.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS D05: 108 regressions, XSim, A53, original project, module timing, input hashes; no full-core/board claim')
