"""Independent batch oracle versus bounded causal stream model (D05 reference)."""
from pathlib import Path
import random,sys,unittest
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from online_statistics_model import OnlineStatistics
class OnlineStatisticsTests(unittest.TestCase):
 def test_hold_bound_and_tail_exclusion(self):
  rng=random.Random(605)
  for hold in (1,125,256):
   for length in (1,3,4,27,15500,16384):
    powers=[tuple(rng.randrange(0,100000) for _ in range(6)) for _ in range(length)]
    noise=(100,200,300,400,500,600);model=OnlineStatistics()
    begin=20;end=begin+length;result=None
    for seq in range(end+hold+model.delay+8):
     if seq==begin+2:self.assertTrue(model.start((7,9),begin,noise,hold))
     if seq==end+hold+2:model.end((7,9),end)
     p=powers[seq-begin] if begin<=seq<end else (0x80000000,)*6
     model.clock(seq,p)
     if model.peek((7,9)) is not None:result=model.peek((7,9))
    self.assertEqual(result['count'],length)
    self.assertEqual(result['energy'],tuple(sum(p[c] for p in powers) for c in range(6)))
    self.assertEqual(result['peak'],tuple(max(p[c] for p in powers) for c in range(6)))
    top=[]
    for c in range(6):
     net=[max(p[c]-noise[c],0) for p in powers]
     top.append(max((sum(net[i:i+4])//4 for i in range(len(net)-3)),default=0))
    self.assertEqual(result['top_signal'],tuple(top))
    self.assertEqual(result['p50'],tuple(noise[c]+top[c]//2 for c in range(6)))
    self.assertEqual(result['bad'],0)
    self.assertEqual(result['error'],0)
 def test_capacity_identity_and_gaps(self):
  m=OnlineStatistics()
  self.assertFalse(m.start((0,1),10,(0,)*6,257))
  for k in range(4):self.assertTrue(m.start((0,k),10,(0,)*6,125))
  self.assertFalse(m.start((0,0),10,(0,)*6,125))
  self.assertFalse(m.start((0,9),10,(0,)*6,125))
  self.assertFalse(m.end((1,0),20))
  for k in range(4):self.assertTrue(m.end((0,k),20))
  for s in range(320):m.clock(s,(1,)*6,good=0x3f if s!=13 else 0x3e)
  for k in range(4):
   r=m.peek((0,k));self.assertEqual(r['bad'],1);self.assertEqual(r['count'],10)
  self.assertFalse(m.pop((1,0)));self.assertTrue(m.pop((0,0)));self.assertFalse(m.pop((0,0)))
  self.assertTrue(m.start((0,9),400,(0,)*6,125))
 def test_late_eop_rejects_instead_of_rewriting_committed_statistics(self):
  m=OnlineStatistics();self.assertTrue(m.start((0,1),0,(0,)*6,256))
  for s in range(400):m.clock(s,(25,)*6)
  self.assertTrue(m.end((0,1),20))
  r=m.peek((0,1));self.assertNotEqual(r['error'],0);self.assertEqual(r['bad'],0x3f)
if __name__=='__main__':unittest.main()
