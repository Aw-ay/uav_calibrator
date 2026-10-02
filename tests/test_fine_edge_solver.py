from pathlib import Path
import random,subprocess,tempfile,sys
from dataclasses import replace
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from fine_fixed import edge_pair_q16
from fine_edge_program import source,candidate_reference

def generate(td):
 rng=random.Random(748);cases=[]
 for rising in [True,False]:
  for m,k in [(8,3),(5,0),(6,1),(7,2),(4,2),(3,1),(2,0)]:
   for noise in [0,1,100,1000000]:
    p=[max(0,5000+(j-k)*1000)*(1 if noise<1000 else 10000) for j in range(m)]
    if not rising:p=p[::-1]
    th=(p[k]+p[k+1])//2;cases.append((p,k,th,noise,rising))
 for _ in range(60):
  p=[rng.randrange(1<<31) for _ in range(8)];k=3;th=(p[k]+p[k+1])//2
  cases.append((p,k,th,rng.randrange(1<<30),p[k]<p[k+1]))
 for _ in range(200):
  step=rng.randrange(1,200000000);base=rng.randrange(1,1000000)
  p=[base+j*step+rng.randrange(max(1,step//10)) for j in range(8)]
  rising=bool(rng.randrange(2))
  if not rising:p.reverse()
  lo,hi=sorted(p[3:5]);th=rng.randrange(lo+1,hi+1)
  cases.append((p,3,th,rng.randrange(1<<31),rising))
 # Exactly zero/negative OLS slope, ringing, wrong bracket, maximal variance.
 cases += [([0,0,0,1,2,0,0,0],3,2,1,True),([1]*8,3,1,1,True),
           ([1,2,3,4,5,6,7,8],3,5,1<<31,True),
           ([0,0,0,0,1<<31,1<<31,1<<31,1<<31],3,1<<30,1<<31,True)]
 rows=[];valid=0
 for c,(p,k,t,noise,rising) in enumerate(cases):
  e=edge_pair_q16(p,k,t,noise,rising);base=rng.randrange(16000)
  if e.valid:e=replace(e,index_q16=e.index_q16+(base<<16),two_q16=e.two_q16+(base<<16),fit_q16=e.fit_q16+(base<<16));valid+=1
  modeled,cycles=candidate_reference(p,k,base+k,t,noise,rising)
  assert modeled==e,(modeled,e)
  data=sum(v<<(32*j) for j,v in enumerate(p))
  inp=data|(len(p)<<256)|(k<<260)|((base+k)<<263)|(t<<278)|(noise<<310)|(int(rising)<<342)
  out=e.index_q16|(e.two_q16<<32)|(e.fit_q16<<64)|(e.variance_two_q32<<96)|(e.variance_fit_q32<<160)|(int(e.valid)<<224)|(e.quality<<225)
  rows.append(f'{inp|(out<<343)|(cycles<<584):0154x}')
 (td/'edge.hex').write_text('\n'.join(rows));return len(rows),valid

if __name__=='__main__':
 assert (ROOT/'rtl/generated/fine_edge_program_pkg.sv').read_text()==source(),'microcode drift'
 if len(sys.argv)==3 and sys.argv[1]=='--vectors':
  td=Path(sys.argv[2]);td.mkdir(parents=True,exist_ok=True);print(generate(td));sys.exit(0)
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);n,valid=generate(td);sim=str(td/'sim')
  for fast in [0,1]:
   p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_edge_solver',f'-Ptb_fine_edge_solver.FAST_MATH={fast}','-o',sim,
    'rtl/generated/fine_edge_program_pkg.sv','rtl/fine/fine_fast_math.sv','rtl/fine/fine_wide_math.sv','rtl/fine/fine_edge_solver.sv',
    'tb/unit/tb_fine_edge_solver.sv'],cwd=ROOT,capture_output=True,text=True)
   assert p.returncode==0,p.stdout+p.stderr
   p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={n}'],capture_output=True,text=True,timeout=180)
   (ROOT/f'reports/v06_fine_edge_solver_fast{fast}.log').write_text(p.stdout+p.stderr)
   assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
   print(p.stdout,f'valid cases={valid}')
