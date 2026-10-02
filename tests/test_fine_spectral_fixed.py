import math,random,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from fine_fixed import spectral_fixed,hv_phase_fixed,measure_fixed
from fine_reference import _spectral,FineConfig

def iq(f,k=0,phase=0,amplitude=20000,n=1024):
 return [(round(amplitude*math.cos(phase+2*math.pi*(f*j/125e6+.5*k*(j/125e6)**2))),round(amplitude*math.sin(phase+2*math.pi*(f*j/125e6+.5*k*(j/125e6)**2)))) for j in range(n)]

class TestSpectralFixed(unittest.TestCase):
 def test_segment_against_float_same_quantized_iq(self):
  for f,k in [(3e6,2e11),(-8e6,-5e11),(0,0),(50e6,0),(-50e6,0)]:
   samples=iq(f,k);r=spectral_fixed(samples,24,1000,(20,1005))
   self.assertTrue(r['valid'],r)
   ref=_spectral([complex(i,q) for i,q in samples],24,1000,(20,1005),FineConfig())
   self.assertEqual(ref[2],0);self.assertAlmostEqual(r['frequency_hz'],ref[0],delta=1);self.assertAlmostEqual(r['chirp_hz_per_s'],ref[1],delta=1e7)
   self.assertAlmostEqual(r['frequency_hz'],f,delta=100);self.assertAlmostEqual(r['chirp_hz_per_s'],k,delta=1e8)
 def test_hv_sign_unequal_gain(self):
  r=hv_phase_fixed(iq(3e6,phase=.6),iq(3e6,phase=-.2,amplitude=2000),24,1000)
  self.assertTrue(r['valid']);self.assertAlmostEqual(r['phase_q31']/(1<<31),.8/(2*math.pi),delta=1e-5)
 def test_full_batch_against_analytic_pulse(self):
  import cmath
  samples=[]
  for n in range(256):
   power=16+1000000*max(0,min(1,.5+(n-20.25)/8,.5+(210.75-n)/8))
   z=cmath.rect(math.sqrt(power),2*math.pi*5e6*n/125e6)
   samples.append((round(z.real),round(z.imag)))
  r=measure_fixed(samples,samples,noise=(16,16),top_signal=(1000000,1000000),coarse=(20,211))
  self.assertTrue(r['h']['timing_valid'] and r['h']['spectral']['valid'] and r['hv']['valid'])
  self.assertAlmostEqual(r['h']['rise'].index_q16/65536,20.25,delta=.01)
  self.assertAlmostEqual(r['h']['fall'].index_q16/65536,210.75,delta=.01)
  self.assertAlmostEqual(r['h']['spectral']['frequency_hz'],5e6,delta=1000)
  self.assertEqual(r['hv']['phase_q31'],0)
 def test_full_depth_extrema(self):
  samples=[(-32768,-32768)]*16384
  self.assertEqual(spectral_fixed(samples,0,16383,(0,16384))['frequency_hz'],0)
  self.assertEqual(hv_phase_fixed(samples,samples,0,16383)['phase_q31'],0)
 def test_quality_failures(self):
  self.assertEqual(spectral_fixed(iq(1e6),0,7,(0,8))['quality'],1)
  self.assertEqual(spectral_fixed([(0,0)]*32,0,31,(0,32))['quality'],4)
  self.assertEqual(spectral_fixed(iq(.495*125e6),24,1000,(20,1005))['quality'],8)
  rng=random.Random(71);noise=[(rng.randrange(-1000,1001),rng.randrange(-1000,1001)) for _ in range(1024)]
  self.assertEqual(spectral_fixed(noise,24,1000,(20,1005))['quality'],32)
if __name__=='__main__':unittest.main(verbosity=2)
