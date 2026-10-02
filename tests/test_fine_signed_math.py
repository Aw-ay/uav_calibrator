from pathlib import Path
import random,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(7257);rows=[];mask=(1<<256)-1
for op in range(4):
 for _ in range(80):
  a=rng.getrandbits(rng.choice([16,64,128,256]));b=rng.getrandbits(rng.choice([0,16,64,256]));sa=rng.randrange(2);sb=rng.randrange(2)
  x=-a if sa else a;y=-b if sb else b;fault=op==3 and b==0
  if op==0:z=x+y
  elif op==1:z=x-y
  elif op==2:z=x*y
  elif not b:z=0
  else:
   q,r=divmod(a,b);q+=2*r>=b;z=-q if sa!=sb else q
  fault|=abs(z)>mask
  v=a|(b<<256)|(sa<<512)|(sb<<513)|(op<<514)|((abs(z)&mask)<<516)|(int(z<0)<<772)|(fault<<773)
  rows.append(f'{v:0194x}')
with tempfile.TemporaryDirectory() as tmp:
 td=Path(tmp);(td/'signed.hex').write_text('\n'.join(rows));sim=str(td/'sim')
 for fast in [0,1]:
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_signed_math',f'-Ptb_fine_signed_math.FAST_MATH={fast}','-o',sim,'rtl/fine/fine_fast_math.sv','rtl/fine/fine_wide_math.sv','rtl/fine/fine_signed_math.sv','tb/unit/tb_fine_signed_math.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={len(rows)}'],capture_output=True,text=True,timeout=120)
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
  (ROOT/f'reports/v06_fine_signed_math_fast{fast}.log').write_text(p.stdout+p.stderr);print(p.stdout)
