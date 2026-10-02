from pathlib import Path
import math,random,sys,tempfile,subprocess
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tests')]
from fine_fixed import measure_fixed
from test_fine_stream import pulse

def generate(td):
 samples=[];jobs=[];rng=random.Random(9012)
 for case in range(31):
  n=[1,2,3,4,8,16,31,32,33,64,128,256,16384][case%13]
  if case>=25:n=256
  a,b=(min(30,n//4),max(1,n-min(30,n//4)))
  h=pulse(n,a,b);v=pulse(n,a,b,.43,case==11)
  if case==14:h=[(0,0)]*n
  if case==15:v=[(-32768,-32768)]*n
  if case==24:
   h=[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(n)]
   v=h[:]
  noise=[1000,1000];top=[121000000]*2;good=3;known=3
  if case==20:noise=[100000000,0]
  if case==21:good=1
  if case==22:known=2
  if case==23:top=[0,121000000]
  if case>=25:
   def shaped(left,right,amp,phase):
    return [(round(max(0,min(1,(k-left+4)/8,(right-k+4)/8))*amp*math.cos(phase(k))),
             round(max(0,min(1,(k-left+4)/8,(right-k+4)/8))*amp*math.sin(phase(k)))) for k in range(n)]
   slope={25:0,26:-.7,27:.9,28:.03,29:-.04,30:.05}[case]
   chirp={28:.001,29:-.001}.get(case,0)
   h=shaped(a-(2 if case==30 else 0),b+(1 if case==30 else 0),11000,lambda k:slope*k+chirp*k*k)
   v=shaped(a+(2 if case==30 else 0),b-(2 if case==30 else 0),9000 if case==30 else 11000,lambda k:slope*k+chirp*k*k+(1.7 if case==30 else .43))
   if case==30:top[1]=81000000;noise=[73,911]
  g=measure_fixed(h,v,noise=noise,top_signal=top,coarse=(a,b),source_good=[bool(good&1),bool(good&2)],noise_known=[bool(known&1),bool(known&2)])
  header=0x40001|(case<<64)|(9<<128)|(17<<192)|(42<<256)|(1<<288)|(5<<296)|(1<<304)|(123456<<320)
  fields=[(header,384)];valid=0;edgeq=0;specq=0
  for p,key in enumerate(['h','v']):
   r=g[key];valid|=int(r['timing_valid'])<<p;valid|=int(r['spectral']['valid'])<<(p+2)
   fields.extend([(r['rise'].index_q16,32),(r['fall'].index_q16,32)])
   edgeq|=r['edge_quality']<<(16*p);specq|=r['spectral']['quality']<<(8*p)
  peaks=[max(i*i+q*q for i,q in s) for s in [h,v]]
  fields.extend((v,32) for v in peaks)
  fields.extend((g[k]['mean_body_power'],32) for k in ['h','v'])
  fields.extend((g[k]['spectral'].get('frequency_hz',0),32) for k in ['h','v'])
  fields.extend((g[k]['spectral'].get('chirp_hz_per_s',0),64) for k in ['h','v'])
  fields.append((g['hv'].get('phase_q31',0),32))
  fields.extend((g[k]['snr_q16'],32) for k in ['h','v'])
  specq|=g['hv']['quality']<<16;valid|=int(g['hv']['valid'])<<4
  fields.extend([(edgeq,32),(specq,32),(0,32)])
  expected=pos=0
  for value,width in fields:expected|=(value&((1<<width)-1))<<pos;pos+=width
  assert pos==1024
  expected|=valid<<312
  # flags bits 0/1 explicitly indicate SNR saturation in engine transport revision3.
  expected|=(int(g['h']['snr_saturated'])|(int(g['v']['snr_saturated'])<<1))<<32
  job=pos=0
  for value,width in [(len(samples),32),(n,15),(16383 if case%2 or n==16384 else 0,14),(a,15),(b,15),(noise[0]|noise[1]<<32,64),(top[0]|top[1]<<32,64),(peaks[0]|peaks[1]<<32,64),(good,2),(known,2),(header,384),(expected,1024)]:
   job|=value<<pos;pos+=width
  jobs.append(f'{job:0450x}')
  samples.extend(f'{sum((x&65535)<<(16*j) for j,x in enumerate((*hi,*vi))):016x}' for hi,vi in zip(h,v))
 (td/'jobs.hex').write_text('\n'.join(jobs));(td/'samples.hex').write_text('\n'.join(samples));return len(jobs),len(samples)

if __name__=='__main__':
 if '--vectors' in sys.argv:
  td=Path(sys.argv[sys.argv.index('--vectors')+1]);td.mkdir(parents=True,exist_ok=True);print(generate(td));sys.exit(0)
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);jobs,count=generate(td)
  sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/fine_edge_program_pkg.sv','rtl/capture/b_port_reader_128.sv']
  sources+=list(str(p.relative_to(ROOT)) for p in (ROOT/'rtl/fine').glob('*.sv'))
  for latency in [1,2,3]:
   sim=str(td/f'sim{latency}')
   p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_engine',f'-Ptb_fine_engine.LATENCY={latency}','-o',sim,*sources,'tb/unit/tb_fine_engine.sv'],cwd=ROOT,capture_output=True,text=True)
   assert p.returncode==0,p.stdout+p.stderr
   p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={count}',f'+JOBS={jobs}'],capture_output=True,text=True,timeout=600)
   assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
   (ROOT/f'reports/v06_fine_engine_l{latency}.log').write_text(p.stdout+p.stderr);print(p.stdout)
