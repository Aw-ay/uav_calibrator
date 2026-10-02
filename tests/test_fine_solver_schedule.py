"""Use measured-equivalent shared solver latency in the bounded local stream model."""
from pathlib import Path
import sys,unittest
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from fine_stream import FinePass
from fine_edge_program import candidate_reference
from fine_fixed import measure_fixed
from test_fine_stream import pulse

class SolverSchedule(unittest.TestCase):
 def test_serial_hv_arithmetic_stalls_do_not_expand_raw_storage(self):
  for ringing in [False,True]:
   h=pulse(256,35,200,ring=ringing);v=pulse(256,37,198,.3,ring=ringing)
   calls=[]
   def service(p,k,index,t,n,rise):
    result,cycles=candidate_reference(p,k,index,t,n,rise);calls.append(cycles);return cycles
   stream=FinePass(256,coarse=(35,200),noise=(1000,1000),top_signal=(121000000,121000000),edge_latency=service)
   off=elapsed=0
   while not stream.done:
    off+=stream.tick((h[off],v[off]) if off<256 else None)
    elapsed+=1;self.assertLess(elapsed,3000000)
   golden=measure_fixed(h,v,coarse=(35,200),noise=(1000,1000),top_signal=(121000000,121000000))
   for pol in ['h','v']:
    for field in ['rise','fall','timing_valid','edge_quality','body_first','body_last']:
     self.assertEqual(stream.result[pol][field],golden[pol][field])
   self.assertEqual(stream.edge_stall_cycles,sum(calls));self.assertEqual(stream.peak_samples,32)
   self.assertTrue(any(c>20000 for c in calls))
   print(f'shared solver schedule ringing={ringing}: candidates={len(calls)}, solver_cycles={sum(calls)}, elapsed={elapsed}, cache_peak=32')

if __name__=='__main__':unittest.main()
