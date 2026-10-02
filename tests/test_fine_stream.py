"""A batch oracle may see RAW; the DUT only receives one currently available IQ pair."""
from pathlib import Path
import math,random,sys,unittest
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from fine_fixed import measure_fixed, _product
from fine_stream import FinePass

def pulse(size,a,b,offset=0,ring=False):
 result=[]
 for n in range(size):
  amp=max(0,min(1,(n-a+4)/8,(b-n+4)/8))*11000
  if ring and abs(n-b)<8:amp*=1+.7*math.sin(n*1.7)
  angle=.017*n+.000001*n*n+offset
  result.append((round(amp*math.cos(angle)),round(amp*math.sin(angle))))
 return result

class FineStreamTests(unittest.TestCase):
 def check_case(self,h,v,coarse,noise=(1000,1000),top=(121000000,121000000),latency=33):
  golden=measure_fixed(h,v,noise=noise,top_signal=top,coarse=coarse)
  dut=FinePass(len(h),coarse=coarse,noise=noise,top_signal=top,edge_latency=latency)
  rng=random.Random(len(h)+coarse[0]);off=cycles=0
  while not dut.done:
   offered=(h[off],v[off]) if off<len(h) and rng.random()<.81 else None
   taken=dut.tick(offered,retire_ready=rng.random()<.78)
   off+=taken;cycles+=1
   self.assertLess(cycles,len(h)*12+latency*75+1000)
   self.assertLessEqual(dut.peak_samples,32)
  self.assertEqual(off,len(h));self.assertEqual(dut.retired,len(h))
  for pol,key,samples in [(0,'h',h),(1,'v',v)]:
   g=golden[key];s=dut.result[key]
   for name in ['rise','fall','timing_valid','edge_quality','body_first','body_last']:
    self.assertEqual(s[name],g[name],(key,name,coarse))
   bins=[[0]*6 for _ in range(8)];energy=count=0
   if g['timing_valid']:
    lo,hi=g['body_first'],g['body_last']
    for n in range(lo,hi+1):energy+=sum(x*x for x in samples[n]);count+=1
    for n in range(lo+1,hi+1):
     which=max(0,min(7,((2*n-1-2*coarse[0])*8)//(2*(coarse[1]-coarse[0]))))
     re,im=_product(samples[n],samples[n-1]);r=bins[which]
     r[0]+=re;r[1]+=im;r[2]+=2*n-1;r[3]+=1
     r[4]+=sum(x*x for x in samples[n]);r[5]+=sum(x*x for x in samples[n-1])
   self.assertEqual(s['bins'],bins);self.assertEqual(s['energy'],energy);self.assertEqual(s['count'],count)
  cross=[0]*5
  if all(golden[p]['timing_valid'] for p in ['h','v']):
   lo=max(golden[p]['body_first'] for p in ['h','v']);hi=min(golden[p]['body_last'] for p in ['h','v'])
   for n in range(lo,hi+1):
    re,im=_product(h[n],v[n]);cross[0]+=re;cross[1]+=im
    cross[2]+=sum(x*x for x in h[n]);cross[3]+=sum(x*x for x in v[n]);cross[4]+=1
  self.assertEqual(dut.result['hv_sums'],cross)
  return dut

 def test_full_length_and_long_finalize_stalls(self):
  n=16384
  d=self.check_case(pulse(n,30,n-30),pulse(n,32,n-28,.42),(30,n-30),latency=257)
  self.assertEqual(d.peak_samples,32)
  self.assertGreater(d.edge_stall_cycles,0)

 def test_clipped_short_and_missing_edges(self):
  for n in [1,2,3,4,8,16,31,32,33,64]:
   self.check_case(pulse(n,0,n-1),pulse(n,1,n-2,.3),(0,max(1,n-1)))
   self.check_case([(0,0)]*n,[(32767,-32768)]*n,(0,n))

 def test_displaced_edges_and_ringing(self):
  for shift in range(-8,9):
   self.check_case(pulse(192,40+shift,130-shift),pulse(192,42+shift,128-shift,.6),(40,130))
  self.check_case(pulse(192,40,130,ring=True),pulse(192,41,132,.7,ring=True),(40,130))

 def test_random_iq_and_low_snr(self):
  rng=random.Random(7032)
  for case in range(30):
   n=rng.randrange(5,160);a=rng.randrange(n-1);b=rng.randrange(a+1,n+1)
   h=[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(n)]
   v=[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(n)]
   self.check_case(h,v,(a,b),noise=(100,100),top=(700000000,700000000),latency=1)
  self.check_case(pulse(128,20,90),pulse(128,20,90),(20,90),noise=(100000000,0))

if __name__=='__main__':unittest.main()
