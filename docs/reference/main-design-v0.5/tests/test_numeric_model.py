"""Independent numerical/queue checks. These do not replace RTL simulation."""
import importlib
import sys
import unittest
from pathlib import Path
import numpy as np
from scipy import signal
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))

class Models(unittest.TestCase):
    def setUp(self):
        self.assertTrue((ROOT/'models'/'numeric_model.py').exists(), 'Numerical and queue models have not been implemented')
        self.m = importlib.import_module('models.numeric_model')

    def test_round_ties_even_signed(self):
        a=np.array([-7,-5,-3,-1,1,3,5,7],dtype=np.int64)
        np.testing.assert_array_equal(self.m.round_shift(a,1),[-4,-2,-2,0,0,2,2,4])

    def test_stream_history_and_decimation_phase(self):
        q=np.array([3,-5,8,-5,3],np.int64)
        x=np.arange(-31,48,dtype=np.int64).reshape(-1,1)
        obj=self.m.FixedDecimator(q,2,0,24,1)
        parts=[obj.process(x[:3]),obj.process(x[3:20]),obj.process(x[20:21]),obj.process(x[21:])]
        reference=np.convolve(x[:,0],q)[:len(x)][::2]
        np.testing.assert_array_equal(np.concatenate(parts)[:,0],reference)

    def test_input_pack_4_8_equivalent(self):
        rng=np.random.default_rng(9341)
        x=rng.integers(-8192,8192,(8192,16),dtype=np.int64)<<8
        stages=self.m.recommended_stages()
        a=self.m.run_packed_rx(x,stages,4)
        b=self.m.run_packed_rx(x,stages,8)
        np.testing.assert_array_equal(a,b)

    def test_multistage_polyphase_matches_equivalent(self):
        rng=np.random.default_rng(12);x=rng.normal(size=4096)
        st=self.m.recommended_stages();h1=st[0]['q']/2**17;h2=st[1]['q']/2**17
        y=signal.upfirdn(h2,signal.upfirdn(h1,x,down=2),down=2)
        he=self.m.equivalent(st)
        expected=signal.upfirdn(he,x,down=4)
        np.testing.assert_allclose(y[:len(expected)],expected,atol=3e-15,rtol=1e-13)

    def test_recommended_strict_100mhz(self):
        st=self.m.recommended_stages();r=self.m.metrics(self.m.equivalent(st),500e6,50e6,62.5e6)
        self.assertLess(r['ripple_db'],0.1);self.assertGreater(r['stop_db'],70)
        self.assertEqual(len(st[1]['q']),75)

    def test_halband_zeros_center_symmetry(self):
        q=self.m.recommended_stages()[0]['q'];c=len(q)//2
        self.assertEqual(q[c],2**16)
        np.testing.assert_array_equal(q,q[::-1])
        self.assertTrue(np.all(q[np.arange(len(q))%2==c%2][np.arange(len(q)//2)!=c//2]==0))

    def test_continuous_overflow_matches_rate_formula(self):
        r=self.m.continuous_queue(4e9,2.4e9,65536,100e-6,dt=8e-9)
        expected=65536/(4e9-2.4e9)
        self.assertLessEqual(abs(r['first_overflow_s']-expected),8.1e-9)

    def test_packet_queue_fast_sink_no_loss(self):
        r=self.m.packet_queue(duration=.1,fs_out=125e6,prf=1000,window=126e-6,
             groups=4,banks=4,dma_rate=2.4e9,storage_rate=2e9,slots=512)
        self.assertEqual(r['lost_records'],0)
        self.assertEqual(r['accepted_records'],400)

    def test_packet_queue_slow_sink_finite_buffers(self):
        r=self.m.packet_queue(duration=.4,fs_out=125e6,prf=3300,window=126e-6,
             groups=4,banks=2,dma_rate=2.4e9,storage_rate=.1e9,slots=8)
        self.assertGreater(r['lost_records'],0)

    def test_slot_too_small_rejected(self):
        with self.assertRaises(ValueError):
            self.m.packet_queue(duration=.01,fs_out=125e6,prf=1000,window=131.072e-6,
              groups=4,banks=4,dma_rate=2.4e9,storage_rate=2e9,slots=512,slot_bytes=131072)

    def test_full_scale_step_uses_integer_guard_bits(self):
        x=np.zeros((4096,1),dtype=np.int64);x[256:2048]=32767<<6
        y,stats=self.m.run_fixed_rx(x,self.m.recommended_stages())
        self.assertEqual(sum(st['clips'] for st in stats['stages']),0)
        # Narrowing back to IQ16 needs separate saturation handling, not silent wrapping.
        self.assertGreater(np.count_nonzero(self.m.round_shift(y,6)>32767),0)

    def test_service_blackout(self):
        finish=self.m.finish_service(.009,2e6,1e9,.010,.002)
        self.assertAlmostEqual(finish,.013,places=12)

    def test_tx_float_interpolation_gain(self):
        stages=self.m.recommended_stages();x=np.ones(2048)
        z=x
        for st in stages[::-1]: z=signal.upfirdn(st['q']/2**17*2,z,up=2)
        self.assertLess(abs(np.mean(z[400:-400])-1),.001)

