"""Cycle-exact natural B128 -> local 32-sample cache, including cancellation."""
from pathlib import Path
import random, subprocess, sys, tempfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from fine_stream import SampleCache

# Order is shared with the small vector TB; expectations come from Python queues.
INPUT=[('rst',1),('abort',1),('job_valid',1),('job_count',15),('job_odd',1),
       ('word_valid',1),('word_data',128),('word_mask',2),('word_index',15),
       ('word_first',1),('word_last',1),('sample_ready',1),
       ('peek_req_valid',1),('peek_index',15),('peek_ready',1)]
OUTPUT=[('job_ready',1),('word_ready',1),('sample_valid',1),('sample_data',64),
        ('sample_index',15),('sample_last',1),('occupancy',6),('busy',1),
        ('done',1),('error',1),('peek_req_ready',1),('peek_valid',1),
        ('peek_found',1),('peek_data',64),('peek_result_index',15)]

def pack(row,fields):
 value=shift=0
 for name,width in fields:
  value|=(int(row.get(name,0))&((1<<width)-1))<<shift;shift+=width
 return value,shift

def vectors():
 rng=random.Random(70732);model=SampleCache();rows=[];seen=[]
 def cycle(**kw):
  inp={k:0 for k,_ in INPUT};inp.update(kw)
  out=model.observe(inp)
  v,nb=pack(inp,INPUT);w,nw=pack(out,OUTPUT)
  rows.append(f'{v|(w<<nb):0{(nb+nw+3)//4}x}')
  model.clock(inp)
  return out
 cycle(rst=1)
 for length,odd in [(1,0),(1,1),(2,1),(3,0),(31,1),(32,0),(33,1),(16384,0),(16384,1)]:
  cycle(job_valid=1,job_count=length,job_odd=odd)
  accepted=retired=0;words=0;cycles=0;held=None
  samples=[rng.getrandbits(64) for _ in range(length)]
  while model.busy or model.peek_valid:
   cycles+=1;assert cycles<length*8+300
   # Repeated long full-cache stalls; query both retained and absent samples.
   ready=cycles%193>=71 and rng.random()<.82
   kw=dict(sample_ready=ready,peek_ready=rng.random()<.7,
           peek_req_valid=rng.random()<.6,peek_index=max(0,retired+rng.randrange(-3,36)))
   if held is None and accepted<length and rng.random()<.87:
    mask=2 if accepted==0 and odd else (1 if length-accepted==1 else 3)
    n=mask.bit_count();data=samples[accepted]<<64 if mask==2 else samples[accepted]
    if mask==3:data|=samples[accepted+1]<<64
    held=dict(word_valid=1,word_data=data,word_mask=mask,word_index=accepted,
              word_first=accepted==0,word_last=accepted+n==length)
   if held:kw.update(held)
   out=cycle(**kw)
   if out['sample_valid'] and ready:
    assert out['sample_index']==retired and out['sample_data']==samples[retired]
    assert out['sample_last']==(retired==length-1);retired+=1
   if held and out['word_ready']:
    accepted+=held['word_mask'].bit_count();words+=1;held=None
  assert retired==length
  assert words==(length+odd+1)//2
  seen.append((length,odd,cycles))
  cycle(peek_ready=1)
 # Rejected jobs, malformed sequence/mask/last; no silent truncation.
 for length in [0,16385]:
  cycle(job_valid=1,job_count=length);assert model.error and not model.busy
 for change in [dict(word_mask=0),dict(word_mask=2),dict(word_index=1),dict(word_first=0),dict(word_last=1)]:
  cycle(job_valid=1,job_count=4)
  kw=dict(word_valid=1,word_mask=3,word_index=0,word_first=1,word_last=0)
  kw.update(change);cycle(**kw);assert model.error and not model.busy
 for cancel in ['abort','rst']:
  cycle(job_valid=1,job_count=4)
  cycle(word_valid=1,word_mask=3,word_first=1,word_data=99)
  cycle(peek_req_valid=1,peek_index=0)
  cycle(**{cancel:1},word_valid=1,word_mask=3,word_index=2,word_last=1,sample_ready=1)
  assert not model.busy and not model.peek_valid
 cycle()
 return rows,seen

if __name__=='__main__':
 rows,seen=vectors()
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);(td/'cache.hex').write_text('\n'.join(rows));sim=str(td/'sim')
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_sample_cache','-o',sim,
      'rtl/fine/fine_sample_cache.sv','tb/unit/tb_fine_sample_cache.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={len(rows)}'],capture_output=True,text=True,timeout=90)
  (ROOT/'reports/v06_fine_sample_cache.log').write_text(p.stdout+p.stderr)
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
  print(p.stdout,seen)
