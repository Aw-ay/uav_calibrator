from pathlib import Path
import random,math,sys,tempfile,subprocess
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from fine_fixed import spectral_fixed,hv_phase_fixed,_product

def generate(td):
 rng=random.Random(7099);vectors=[]
 for case in range(18):
  n=[8,9,32,128,4096,16384][case%6];iq=[[],[]]
  for p in range(2):
   for k in range(n):
    angle=(.035 if case%2 else -.023)*k+.0000007*k*k+p*.9
    sample=(round(12000*math.cos(angle)),round(12000*math.sin(angle)))
    if case==6:sample=(0,0)
    if case==7:sample=(rng.randrange(-32768,32768),rng.randrange(-32768,32768))
    if case==8:sample=(-32768,-32768)
    if case==9:sample=(12000 if k%2 else -12000,0)
    iq[p].append(sample)
  edges=[case!=10,case!=11];noise=[0 if case%3==0 else 12345,777]
  rows=[];energies=[];counts=[];expected=[]
  for p in range(2):
   bins=[[0]*6 for _ in range(8)];samples=iq[p]
   for k in range(1,n):
    row=bins[min(7,((2*k-1)*8)//(2*n))];re,im=_product(samples[k],samples[k-1])
    row[0]+=re;row[1]+=im;row[2]+=2*k-1;row[3]+=1
    row[4]+=sum(x*x for x in samples[k]);row[5]+=sum(x*x for x in samples[k-1])
   for re,im,center,count,e0,e1 in bins:
    rows.append((re&((1<<48)-1))|((im&((1<<48)-1))<<48)|(center<<96)|(count<<128)|(e0<<143)|(e1<<189))
   energy=sum(i*i+q*q for i,q in samples);energies.append(energy);counts.append(n)
   spec=spectral_fixed(samples,0,n-1,(0,n)) if edges[p] else dict(valid=False,quality=16)
   mean=energy//n if edges[p] else 0
   snr=((max(mean-noise[p],0)<<16)//noise[p] if noise[p] else 1<<32) if edges[p] else 0
   expected.append((mean,min(snr,0xffffffff),snr>0xffffffff,spec))
  re=im=0
  for h,v in zip(*iq):
   r,i=_product(h,v);re+=r;im+=i
  hv=hv_phase_fixed(*iq,0,n-1) if all(edges) else dict(valid=False,quality=16)
  inp=sum(v<<(235*j) for j,v in enumerate(rows))
  pos=3760
  for v,width in [(energies[0],46),(energies[1],46),(n,15),(n,15),
   (re,48),(im,48),(energies[0],46),(energies[1],46),(n,15),(noise[0],32),(noise[1],32),(int(edges[0])|(int(edges[1])<<1),2)]:
   inp|=(v&((1<<width)-1))<<pos;pos+=width
  assert pos==4151
  means=sum(e[0]<<(32*p) for p,e in enumerate(expected));snrs=sum(e[1]<<(32*p) for p,e in enumerate(expected))
  sat=sum(int(e[2])<<p for p,e in enumerate(expected));valid=sum(int(e[3]['valid'])<<p for p,e in enumerate(expected))|(int(hv['valid'])<<2)
  qual=sum(e[3]['quality']<<(8*p) for p,e in enumerate(expected))|(hv['quality']<<16)
  frequencies=sum((e[3].get('frequency_hz',0)&0xffffffff)<<(32*p) for p,e in enumerate(expected))
  chirps=sum((e[3].get('chirp_hz_per_s',0)&((1<<64)-1))<<(64*p) for p,e in enumerate(expected))
  out=means|(snrs<<64)|(sat<<128)|(valid<<130)|(qual<<133)|(frequencies<<157)|(chirps<<221)|((hv.get('phase_q31',0)&0xffffffff)<<349)
  vectors.append(f'{inp|(out<<4151):01133x}')
 (td/'finalize.hex').write_text('\n'.join(vectors));return len(vectors)

if __name__=='__main__':
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);n=generate(td);sim=str(td/'sim')
  for fast in [0,1]:
   p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_finalize',f'-Ptb_fine_finalize.FAST_MATH={fast}','-o',sim,
    'rtl/fine/fine_fast_math.sv','rtl/fine/fine_wide_math.sv','rtl/fine/fine_signed_math.sv','rtl/fine/fine_cordic.sv',
    'rtl/fine/fine_finalize.sv','tb/unit/tb_fine_finalize.sv'],cwd=ROOT,capture_output=True,text=True)
   assert p.returncode==0,p.stdout+p.stderr
   p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={n}'],capture_output=True,text=True,timeout=300)
   assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
   (ROOT/f'reports/v06_fine_finalize_fast{fast}.log').write_text(p.stdout+p.stderr);print(p.stdout)
