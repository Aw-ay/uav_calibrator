from pathlib import Path
import subprocess,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]
class RecordArbiterTests(unittest.TestCase):
 def test_record_atomicity_and_fairness(self):
  with tempfile.TemporaryDirectory() as temp:
   exe=str(Path(temp)/'sim')
   run=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_record_descriptor_arbiter','-o',exe,str(ROOT/'rtl/data/record_descriptor_arbiter.sv'),str(ROOT/'tb/unit/tb_record_descriptor_arbiter.sv')],capture_output=True,text=True)
   self.assertEqual(run.returncode,0,run.stdout+run.stderr)
   run=subprocess.run(['C:/iverilog/bin/vvp.exe',exe],capture_output=True,text=True)
   self.assertEqual(run.returncode,0,run.stdout+run.stderr);self.assertIn('PASS',run.stdout)
if __name__=='__main__':unittest.main()
