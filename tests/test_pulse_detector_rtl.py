"""Detector behavior: literals catch shifted boundaries, hold-as-payload,
config rewriting, signed-square overflow, silent gaps and default enable.
Runs actual Icarus; no substitute model is accepted as RTL evidence.
"""
import pathlib, random, subprocess, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
IV = pathlib.Path('C:/iverilog/bin/iverilog.exe')
VVP = IV.with_name('vvp.exe')


def windows(powers,on=100,off=25,hold=3):
    result=[]; start=None; last=None
    for seq,p in enumerate(powers):
        if start is None:
            if p>=on: start=last=seq
        elif p>=off: last=seq
        elif seq-last>=hold:
            result.append((start,last+1,seq)); start=None
    return result

class DetectorTests(unittest.TestCase):
    def test_rtl_behavior(self):
        self.assertTrue((ROOT/'rtl/capture/pulse_detector.sv').exists(), 'pulse_detector implementation missing')
        with tempfile.TemporaryDirectory() as tmp:
            out=pathlib.Path(tmp)/'sim.vvp'
            result=subprocess.run([str(IV),'-g2012','-s','tb_pulse_detector','-o',str(out),str(ROOT/'rtl/capture/pulse_detector.sv'),str(ROOT/'tb/unit/tb_pulse_detector.sv')],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            result=subprocess.run([str(VVP),str(out)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('PASS pulse_detector', result.stdout)

    def test_rtl_against_independent_windows(self):
        rng=random.Random(506)
        amps=[0]+[rng.choice([0,1,4,5,6,9,10,11]) for _ in range(1200)]+[0]*3
        expected=windows([a*a for a in amps])
        # Reuse wiring/clock only; expected windows come from Python integers.
        prefix=(ROOT/'tb/unit/tb_pulse_detector.sv').read_text().split(' initial begin')[0]
        body=' initial begin reset_dut();cfg_enable=1;cfg_validated=1;cfg_max_body=15000;\n'
        body+='\n'.join(f'tick({i},{a});' for i,a in enumerate(amps))
        body+='\n#2;$finish;end\nalways @(posedge clk) begin #2; if(event_valid) $display("WINDOW %0d %0d %0d",event_onset_seq,event_end_seq,sample_seq);end\nendmodule\n'
        with tempfile.TemporaryDirectory() as tmp:
            tb=pathlib.Path(tmp)/'random.sv';out=pathlib.Path(tmp)/'sim.vvp'
            tb.write_text(prefix+body)
            result=subprocess.run([str(IV),'-g2012','-s','tb_pulse_detector','-o',str(out),str(ROOT/'rtl/capture/pulse_detector.sv'),str(tb)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            result=subprocess.run([str(VVP),str(out)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            actual=[tuple(map(int,line.split()[1:])) for line in result.stdout.splitlines() if line.startswith('WINDOW ')]
            self.assertEqual(actual,expected)

    def test_independent_window_definition(self):
        # Offline causal definition: merge excursions separated by <hold lows;
        # onset requires >=on, end is last >=off+1, never hold arrival.
        self.assertEqual(windows([0,100,36,0,0,0]),[(1,3,5)])
        self.assertEqual(windows([100,0,0,36,0,0,0]),[(0,4,6)])
        self.assertEqual(sum(x*x for x in [-32768]*4),4294967296)

if __name__=='__main__': unittest.main()
