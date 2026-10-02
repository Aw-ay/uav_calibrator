from pathlib import Path
import random,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from fine_fixed import cordic_phase_q31
rng=random.Random(7007)
values=[(0,0),(1,0),(0,1),(-1,0),(0,-1),(-(1<<47),-(1<<47)),((1<<47)-1,-(1<<47))]
values += [(rng.randrange(-(1<<47),1<<47),rng.randrange(-(1<<47),1<<47)) for _ in range(1000)]
with tempfile.TemporaryDirectory() as tmp:
 td=Path(tmp);rows=[]
 for x,y in values:
  zero=x==0 and y==0;phase=0 if zero else cordic_phase_q31(x,y)
  rows.append(f'{(x&((1<<48)-1))|((y&((1<<48)-1))<<48)|((phase&0xffffffff)<<96)|(int(zero)<<128):033x}')
 (td/'cordic.hex').write_text('\n'.join(rows));sim=str(td/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_cordic','-o',sim,'rtl/fine/fine_cordic.sv','tb/unit/tb_fine_cordic.sv'],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={len(values)}'],capture_output=True,text=True,timeout=60)
 (ROOT/'reports/v06_fine_cordic.log').write_text(p.stdout+p.stderr)
 assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
