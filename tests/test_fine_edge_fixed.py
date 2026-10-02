import math,random,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from fine_fixed import edge_pair_q16,rounded_divide
from fine_reference import _edge,FineConfig
class TestEdgeFixed(unittest.TestCase):
 def test_rounded_division(self):
  for n,want in [(1,1),(-1,-1),(3,2),(-3,-2),(0,0)]:self.assertEqual(rounded_divide(n,2),want)
 def test_linear_and_noisy_ramps(self):
  rng=random.Random(707)
  for falling in (False,True):
   for trial in range(200):
    position=20+rng.random();amplitude=rng.randrange(1000,1000000);noise=20
    p=[max(noise,min(noise+amplitude,round(noise+amplitude*(.5+(-1 if falling else 1)*(n-position)/8)))) for n in range(50)]
    if trial%2:p=[max(0,v+rng.randrange(-3,4)) for v in p]
    threshold=noise+amplitude//2
    candidates=[k for k in range(49) if (p[k]>=threshold>p[k+1] if falling else p[k]<threshold<=p[k+1])]
    k=candidates[-1 if falling else 0]
    got=edge_pair_q16(p,k,threshold,noise,not falling)
    expected=_edge(p,threshold,noise,20,not falling,FineConfig())
    self.assertEqual(got.valid,expected.valid)
    if got.valid:self.assertAlmostEqual(got.index_q16/65536,expected.index,delta=2/65536)
 def test_short_wrong_cross_and_extrema(self):
  self.assertFalse(edge_pair_q16([0,100],0,50,0,True).valid)
  self.assertFalse(edge_pair_q16([0,100,100,0],1,50,0,True).valid)
  p=[0]*20+[1<<31]*20
  got=edge_pair_q16(p,19,1<<30,0,True)
  self.assertTrue(got.valid);self.assertEqual(got.index_q16,(19<<16)+32768)
 def test_variance_overflow_invalid(self):
  p=[1000000000+i for i in range(50)]
  got=edge_pair_q16(p,20,1000000021,1<<30,True)
  self.assertFalse(got.valid);self.assertEqual(got.quality,256)
if __name__=='__main__':unittest.main(verbosity=2)
