"""Candidate solver evidence, preserving the distinction from a complete Fine engine."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,subprocess,sys
from fine_edge_program import PROGRAM
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
names=['test_fine_reference.py','test_fine_fixed.py','test_fine_edge_fixed.py','test_fine_spectral_fixed.py',
 'test_fine_cordic.py','test_fine_stream.py','test_fine_sample_cache.py','test_fine_accumulator.py',
 'test_fine_read_pipeline.py','test_b_port_reader_128.py','test_fine_wide_math.py',
 'test_fine_edge_solver.py','test_fine_solver_schedule.py']
checks=[]
for name in names:
 command=[sys.executable,'-X','utf8','tests/'+name]
 p=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
 checks.append(dict(command=command,exit_code=p.returncode,stdout=p.stdout,stderr=p.stderr))
 print(('PASS' if p.returncode==0 else 'FAIL')+': '+name,flush=True)
 assert p.returncode==0,p.stdout+p.stderr
for path,digest in json.loads((ROOT/'reports/v06_external_baseline.json').read_text()).items():assert sha(ROOT/path)==digest,path
paths=[];modules={}
for filename,marker in [('v06_fine_edge_xsim.log','PASS Fine complete candidate solver 320'),
 ('v06_fine_edge_project_verify.log','DIGITAL_PROJECT_REOPEN_OK'),('v06_fine_edge_synth.log','V06_fine_edge_solver_SYNTH_COMPLETE')]:
 p=ROOT/'reports'/filename;t=p.read_text(errors='replace')
 assert marker in t and not re.search(r'^(ERROR:|FATAL)',t,re.M),filename
 paths.append(p)
for name in ['fine_wide_math','fine_edge_solver']:
 folder=ROOT/'reports/v06_modules'/name;t=(folder/'timing_synth.rpt').read_text()
 m=re.search(r'WNS\(ns\).*?\n.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)',t)
 assert m and all(int(m[i])==0 for i in [3,7,11]) and all(float(m[i])>=0 for i in [1,5,9])
 u=(folder/'utilization.rpt').read_text();resources={}
 for key in ['CLB LUTs*','CLB Registers','Block RAM Tile','DSPs']:
  found=re.search(r'\| '+re.escape(key)+r'\s*\|\s*([\d.]+)',u);assert found,key
  resources[key]=float(found[1])
 modules[name]=dict(wns_ns=float(m[1]),whs_ns=float(m[5]),wpws_ns=float(m[9]),resources=resources)
 paths.extend(folder.glob('*.rpt'))
bound=49+sum(5+[8,8,4354,2578][op] if op<4 else 3 for op,*_ in PROGRAM)
assert bound==135303
paths += [ROOT/p for p in ['contracts/fine_edge_solver.json','tools/fine_edge_program.py','tools/fine_stream.py','tools/fine_fixed.py',
 'tools/verify_v06_fine_edge.py','rtl/generated/fine_edge_program_pkg.sv','rtl/fine/fine_wide_math.sv','rtl/fine/fine_edge_solver.sv',
 'tb/unit/tb_fine_wide_math.sv','tb/unit/tb_fine_edge_solver.sv','hw/tcl/v06_fine_edge.tcl','hw/tcl/v06_fine_edge_tb.tcl',
 'hw/tcl/verify_project.tcl','build/calibrator_zu27dr/calibrator_zu27dr.xpr']]
paths += [ROOT/'tests'/n for n in names]
out=dict(status='PASS',utc=datetime.now(timezone.utc).isoformat(),checks=checks,modules=modules,
 scope='Complete single-candidate edge service, exact data/latency, shared arithmetic and serial-latency causal model; not complete crossing controller/engine or board acceptance',
 candidate_bound_cycles=bound,hashes={p.relative_to(ROOT).as_posix():sha(p) for p in paths})
(ROOT/'reports/v06_fine_edge_delivery.json').write_text(json.dumps(out,indent=2)+'\n')
print('PASS Fine candidate edge: 13 related suites, XSim, original project and200MHz modules; full engine pending')
