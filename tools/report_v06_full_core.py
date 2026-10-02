"""Summarize the requested current-tree synthesis without claiming board closure."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/instrument_v06_online'
snapshot=json.loads((ROOT/'reports/v06_full_core_inputs.json').read_text())
changed=[p for p,h in snapshot['files'].items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
assert not changed,changed
log=(ROOT/'reports/instrument_v06_online.log').read_text(errors='replace')
assert 'INSTRUMENT_V06_ONLINE_SYNTH_COMPLETE' in log and not re.search(r'^ERROR:',log,re.M),'Synthesis incomplete or failed'
t=(OUT/'timing_synth.rpt').read_text()
pat=r'WNS\(ns\).*?\n\s*-+[^\n]*\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)'
m=re.search(pat,t,re.S);assert m
v=m.groups();timing=dict(wns_ns=float(v[0]),tns_ns=float(v[1]),setup_failing=int(v[2]),whs_ns=float(v[4]),hold_failing=int(v[6]),wpws_ns=float(v[8]),pulse_failing=int(v[10]))
cdc_text=(OUT/'cdc.rpt').read_text();cdc=dict(Critical=0,Warning=0,Info=0);cdc_types=[]
for typ,level,count,desc in re.findall(r'^(CDC-\d+)\s+(Critical|Warning|Info)\s+(\d+)\s+([^\n]+)',cdc_text,re.M):
 cdc[level]+=int(count);cdc_types.append(dict(id=typ,severity=level,count=int(count),description=desc.strip()))
constraints={k:int(v) for k,v in re.findall(r'checking (\w+) \((\d+)\)',(OUT/'check_timing.rpt').read_text())}
resources={}
util=(OUT/'utilization.rpt').read_text()
for key in ['CLB LUTs','CLB Registers','Block RAM Tile','DSPs']:
 match=re.search(r'\| '+re.escape(key)+r'\*?\s*\|\s*([\d.]+)',util);assert match,key
 resources[key]=float(match[1])
paths=[]
for kind in ['setup','hold']:
 report=(OUT/(kind+'_paths.rpt')).read_text()
 for block in re.split(r'(?=Slack \()',report)[1:]:
  slack=re.search(r'Slack \([^)]+\)\s*:\s*([-\d.]+)ns',block)
  source=re.search(r'Source:\s*([^\n]+)',block);dest=re.search(r'Destination:\s*([^\n]+)',block)
  group=re.search(r'Path Group:\s*([^\n]+)',block)
  if slack and source and dest:paths.append(dict(kind=kind,slack_ns=float(slack[1]),source=source[1].strip(),destination=dest[1].strip(),group=group[1].strip() if group else None))
status='PASS_SYNTH_ESTIMATE_ONLY' if timing['wns_ns']>=0 and timing['whs_ns']>=0 and not any(timing[k] for k in ['setup_failing','hold_failing','pulse_failing']) and cdc['Critical']==0 else 'ISSUES_FOUND'
report=dict(utc=datetime.now(timezone.utc).isoformat(),status=status,head=snapshot['head'],timing=timing,resources=resources,cdc_unwaived=cdc,cdc_types=cdc_types,constraints=constraints,paths=paths,clock_period_ns=dict(clk_rf=8,clk_mem=5,clk_ctrl=10),input_manifest_sha256=hashlib.sha256((ROOT/'reports/v06_full_core_inputs.json').read_bytes()).hexdigest(),scope='Post-synthesis current digital instrument core; online statistics active; full Fine engine absent and CORDIC not instantiated; FD63 still active; not PS/RFDC board implementation or post-route closure',reports_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.rpt')})
(ROOT/'reports/v06_full_core_review.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['paths','reports_sha256']},indent=2))
print('Worst setup:',next((p for p in paths if p['kind']=='setup'),None))
print('Worst hold:',next((p for p in paths if p['kind']=='hold'),None))
