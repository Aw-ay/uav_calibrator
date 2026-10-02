from pathlib import Path
import random,subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from fine_edge_program import wide_reference

def generate(td):
 rng=random.Random(7256);mask=(1<<256)-1;rows=[]
 for op in range(4):
  pairs=[(0,0),(1,0),(0,1),(mask,1),(mask,mask),(1<<255,1<<255),(5,2),(7,2),(1,2),(1,3),(mask,3)]
  pairs += [(rng.getrandbits(rng.choice([16,48,128,256])),rng.getrandbits(rng.choice([16,48,128,256]))) for _ in range(40)]
  for a,b in pairs:
   for rounding in ([0,1] if op==3 else [0]):
    error=0
    if op==0:value=a+b;error=int(value>mask)
    elif op==1:value=a-b;error=int(value<0)
    elif op==2:value=a*b;error=int(value>mask)
    elif b==0:value=0;error=1
    else:
     value,rem=divmod(a,b)
     if rounding and 2*rem>=b:value+=1
    modeled,failed,cycles=wide_reference(op,a,b,rounding)
    assert modeled==(value&mask) and failed==bool(error)
    row=a|(b<<256)|(op<<512)|(rounding<<514)|((value&mask)<<515)|(error<<771)|(cycles<<772)
    rows.append(f'{row:0197x}')
 (td/'wide.hex').write_text('\n'.join(rows));return len(rows)

if __name__=='__main__':
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);n=generate(td);sim=str(td/'sim')
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_wide_math','-o',sim,
   'rtl/fine/fine_wide_math.sv','tb/unit/tb_fine_wide_math.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={n}'],capture_output=True,text=True,timeout=120)
  (ROOT/'reports/v06_fine_wide_math.log').write_text(p.stdout+p.stderr)
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
  print(p.stdout)
