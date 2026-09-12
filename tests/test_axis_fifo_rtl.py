"""Real simulation of bounded storage, backpressure and AXIS metadata."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AxisFifoTests(unittest.TestCase):
    def test_fifo(self):
        with tempfile.TemporaryDirectory() as temp:
            for address_width in (3, 12):
                exe = str(Path(temp) / f'fifo{address_width}')
                compile_run = subprocess.run([
                    'C:/iverilog/bin/iverilog.exe', '-g2012', '-s', 'tb_axis_record_fifo',
                    f'-Ptb_axis_record_fifo.ADDR_W={address_width}', '-o', exe,
                    str(ROOT / 'rtl/data/axis_record_fifo.sv'),
                    str(ROOT / 'tb/unit/tb_axis_record_fifo.sv')], capture_output=True, text=True)
                self.assertEqual(compile_run.returncode, 0, compile_run.stdout + compile_run.stderr)
                run = subprocess.run(['C:/iverilog/bin/vvp.exe', exe], capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
                self.assertIn('PASS', run.stdout)

if __name__ == '__main__':
    unittest.main()
