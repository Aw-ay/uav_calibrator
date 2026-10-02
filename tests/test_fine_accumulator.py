"""Exact raw sufficient statistics, randomized stream pauses and output ownership."""
from pathlib import Path
import random,subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1]

def generate(td):
 rng=random.Random(7048);inputs=[];expect=[]
 cases=[1,2,9,33,129,16384]
 for case,n in enumerate(cases):
  bins=[[[0]*6 for _ in range(8)] for _ in range(2)];energy=[0,0];count=[0,0];hv=[0]*5;prev=[None,None]
  for index in range(n):
   iq=[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(2)]
   if case==5:iq=[(-32768,-32768),(-32768,32767)]
   keep=[rng.random()<.8,rng.random()<.8] if case<5 else [True,True]
   seg=[min(7,index*8//n),min(7,index*8//n)]
   value=sum((iq[p][c]&65535)<<(16*(2*p+c)) for p in range(2) for c in range(2))
   value|=int(keep[0])<<64|int(keep[1])<<65|seg[0]<<66|seg[1]<<69|index<<72|int(index==n-1)<<87
   inputs.append(f'{value:022x}')
   for p in range(2):
    i,q=iq[p];power=i*i+q*q
    if keep[p]:
     energy[p]+=power;count[p]+=1
     if prev[p] is not None:
      j,r=prev[p];row=bins[p][seg[p]]
      row[0]+=i*j+q*r;row[1]+=q*j-i*r;row[2]+=2*index-1;row[3]+=1;row[4]+=power;row[5]+=j*j+r*r
     prev[p]=iq[p]
    else:prev[p]=None
   if all(keep):
    i,q=iq[0];j,r=iq[1];hv[0]+=i*j+q*r;hv[1]+=q*j-i*r
    hv[2]+=i*i+q*q;hv[3]+=j*j+r*r;hv[4]+=1
  # 16 rows plus one scalar row in same 241-bit transport.
  for p in range(2):
   for row in bins[p]:
    re,im,center,num,e0,e1=row
    packed=(re&((1<<48)-1))|((im&((1<<48)-1))<<48)|(center<<96)|(num<<128)|(e0<<143)|(e1<<189)
    expect.append(f'{packed:059x}')
  re,im,eh,ev,num=hv
  packed=(re&((1<<48)-1))|((im&((1<<48)-1))<<48)|(eh<<96)|(ev<<142)|(num<<188)
  packed|=energy[0]<<203|energy[1]<<249|count[0]<<295|count[1]<<310
  expect.append(f'{packed:082x}')
 (td/'samples.hex').write_text('\n'.join(inputs));(td/'sums.hex').write_text('\n'.join(f'{int(x,16):082x}' for x in expect))
 return sum(cases),len(cases)

if __name__=='__main__':
 if len(sys.argv)==3 and sys.argv[1]=='--vectors':
  td=Path(sys.argv[2]);td.mkdir(parents=True,exist_ok=True);print(generate(td));sys.exit(0)
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);n,jobs=generate(td);sim=str(td/'sim')
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_accumulator','-o',sim,
    'rtl/fine/fine_segment_accumulator.sv','tb/unit/tb_fine_accumulator.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={n}',f'+JOBS={jobs}'],capture_output=True,text=True,timeout=60)
  (ROOT/'reports/v06_fine_accumulator.log').write_text(p.stdout+p.stderr)
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
  print(p.stdout)
