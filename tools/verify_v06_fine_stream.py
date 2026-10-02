"""Re-run affected suites and bind local synthesis evidence; not complete Fine."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
names=['test_fine_reference.py','test_fine_fixed.py','test_fine_edge_fixed.py',
       'test_fine_spectral_fixed.py','test_fine_cordic.py','test_fine_stream.py',
       'test_fine_sample_cache.py','test_fine_accumulator.py','test_fine_read_pipeline.py','test_b_port_reader_128.py']
checks=[]
for name in names:
 command=[sys.executable,'-X','utf8','tests/'+name]
 p=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
 checks.append(dict(command=command,exit_code=p.returncode,stdout=p.stdout,stderr=p.stderr))
 print(('PASS' if p.returncode==0 else 'FAIL')+': '+name,flush=True)
 assert p.returncode==0,p.stdout+p.stderr
for path,digest in json.loads((ROOT/'reports/v06_external_baseline.json').read_text()).items():
 assert sha(ROOT/path)==digest,path
log=(ROOT/'reports/v06_fine_stream_synth.log').read_text(errors='replace')
assert not re.search(r'^(ERROR:|FATAL)',log,re.M)
timing={};paths=[]
for filename,marker in [('v06_fine_read_xsim.log','PASS Fine read/cache/accumulator'),
                        ('v06_fine_stream_project_verify.log','DIGITAL_PROJECT_REOPEN_OK')]:
 logfile=ROOT/'reports'/filename
 content=logfile.read_text(errors='replace')
 assert marker in content and not re.search(r'^(ERROR:|FATAL)',content,re.M),filename
 paths.append(logfile)
for module in ['fine_sample_cache','fine_segment_accumulator']:
 assert 'V06_'+module+'_SYNTH_COMPLETE' in log
 directory=ROOT/'reports/v06_modules'/module
 t=(directory/'timing_synth.rpt').read_text()
 m=re.search(r'WNS\(ns\).*?\n.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)',t)
 assert m and all(int(m[i])==0 for i in [3,7,11]) and all(float(m[i])>=0 for i in [1,5,9])
 resources={};u=(directory/'utilization.rpt').read_text()
 for key in ['CLB LUTs*','CLB Registers','Block RAM Tile','DSPs']:
  match=re.search(r'\| '+re.escape(key)+r'\s*\|\s*([\d.]+)',u);assert match,key
  resources[key]=float(match[1])
 timing[module]=dict(clock_hz=200000000,wns_ns=float(m[1]),whs_ns=float(m[5]),wpws_ns=float(m[9]),resources=resources)
 paths.extend(directory.glob('*.rpt'))
paths += [ROOT/'rtl/fine'/f'{n}.sv' for n in timing]
paths += [ROOT/'tb/unit'/n for n in ['tb_fine_sample_cache.sv','tb_fine_accumulator.sv','tb_fine_read_pipeline.sv']]
paths += [ROOT/'tests'/n for n in names]
paths += [ROOT/p for p in ['contracts/fine_stream.json','tools/fine_stream.py','tools/fine_fixed.py',
 'rtl/capture/b_port_reader_128.sv','hw/tcl/v06_fine_stream.tcl','hw/tcl/v06_fine_read_tb.tcl',
 'hw/tcl/verify_project.tcl','tools/verify_v06_fine_stream.py','build/calibrator_zu27dr/calibrator_zu27dr.xpr']]
report=dict(status='PASS',utc=datetime.now(timezone.utc).isoformat(),checks=checks,modules=timing,
 scope='Causal schedule model plus standalone cache/accumulator RTL and reader composition; edge service ideal in model, body masks supplied by test oracle in RTL integration; no full Fine engine, no board/full-core timing claim',
 hashes={p.relative_to(ROOT).as_posix():sha(p) for p in paths})
(ROOT/'reports/v06_fine_stream_delivery.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS Fine local stream stage: 10 affected suites, XSim, original project, 2 module syntheses; full engine pending')
