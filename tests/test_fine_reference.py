"""Independent analytic pulse truth, not expected values produced by the DUT model."""
import cmath,math,random,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from fine_reference import measure,offline_phase_fit,EDGE_MULTI,EDGE_LOW_SNR,EDGE_NO_RISE,SPEC_TOO_SHORT
FS=125_000_000

def pulse(rise=20.25,fall=190.75,frequency=3_000_000,chirp=2e11,phase=0,n=240,noise=10,top=10000):
 def p(k):return noise+top*max(0,min(1,.5+(k-rise)/8,.5+(fall-k)/8))
 return [cmath.rect(math.sqrt(p(k)),phase+2*math.pi*(frequency*k/FS+.5*chirp*(k/FS)**2)) for k in range(n)]

def run(h,v=None,coarse=(20,191),noise=10,top=10000):
 return measure(h,h if v is None else v,noise=(noise,noise),top_signal=(top,top),coarse=coarse)

class TestFineReference(unittest.TestCase):
 def test_independent_hv_edges_frequency_chirp_and_sign(self):
  h=pulse(phase=.6);v=pulse(rise=23.5,fall=194.125,phase=-.2)
  r=run(h,v,coarse=(20,195));self.assertTrue(r.h.timing_valid and r.v.timing_valid)
  for got,want in [(r.h.rise.index,20.25),(r.h.fall.index,190.75),(r.v.rise.index,23.5),(r.v.fall.index,194.125)]:self.assertAlmostEqual(got,want,places=7)
  for pol,z in [(r.h,h),(r.v,v)]:
   self.assertTrue(pol.spectral_valid)
   f,k=offline_phase_fit(z,pol.body_first,pol.body_last)
   self.assertAlmostEqual(f,3e6,delta=.01);self.assertAlmostEqual(k,2e11,delta=1e4)
   self.assertAlmostEqual(pol.frequency_hz,f,delta=1);self.assertAlmostEqual(pol.chirp_hz_per_s,k,delta=1e6)
  self.assertTrue(r.hv_valid);self.assertAlmostEqual(r.hv_phase_turn,.8/(2*math.pi),places=8)
 def test_negative_frequency_chirp(self):
  r=run(pulse(frequency=-8e6,chirp=-5e11))
  self.assertTrue(r.h.spectral_valid);self.assertAlmostEqual(r.h.frequency_hz,-8e6,delta=1);self.assertAlmostEqual(r.h.chirp_hz_per_s,-5e11,delta=1e6)
 def test_short(self):
  r=run(pulse(rise=20.25,fall=36.75,n=60,chirp=0),coarse=(20,37))
  self.assertTrue(r.h.timing_valid);self.assertFalse(r.h.spectral_valid);self.assertTrue(r.h.spectral_quality&SPEC_TOO_SHORT)
 def test_low_snr_no_rise(self):
  r=run([10+0j]*100,coarse=(20,80),noise=100,top=1)
  self.assertFalse(r.h.timing_valid);self.assertTrue(r.h.edge_quality&EDGE_LOW_SNR);self.assertTrue(r.h.edge_quality&EDGE_NO_RISE)
 def test_half_power(self):
  r=run(pulse(chirp=0));self.assertEqual(r.h.threshold_power,5010);self.assertAlmostEqual(r.h.rise.index,20.25,places=8)
 def test_ringing(self):
  z=pulse(chirp=0);z[17]=complex(math.sqrt(8000),0);z[18]=complex(math.sqrt(100),0)
  self.assertTrue(run(z).h.edge_quality&EDGE_MULTI)
 def test_integer_iq_noise(self):
  rng=random.Random(70);z=pulse(frequency=5e6,chirp=0,top=1_000_000,noise=16)
  q=[complex(round(v.real+rng.gauss(0,math.sqrt(8))),round(v.imag+rng.gauss(0,math.sqrt(8)))) for v in z]
  r=run(q,noise=16,top=1_000_000)
  self.assertTrue(r.h.timing_valid and r.h.spectral_valid);self.assertAlmostEqual(r.h.rise.index,20.25,delta=.05);self.assertAlmostEqual(r.h.frequency_hz,5e6,delta=5000)
 def test_hv_phase_wrap(self):self.assertAlmostEqual(abs(run(pulse(phase=math.pi,chirp=0),pulse(phase=0,chirp=0)).hv_phase_turn),.5,places=8)
 def test_geometry(self):
  with self.assertRaises(ValueError):run([1j]*20,[1j]*19,coarse=(5,15))
if __name__=='__main__':unittest.main(verbosity=2)
