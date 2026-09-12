import json, pathlib, shutil, subprocess, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class ControlRTLTests(unittest.TestCase):
 def test_control_transactions_and_cdc(self):
  iv=shutil.which('iverilog') or 'C:/iverilog/bin/iverilog.exe'
  vv=shutil.which('vvp') or 'C:/iverilog/bin/vvp.exe'
  self.assertTrue(pathlib.Path(iv).exists(), 'iverilog unavailable')
  c=json.loads((ROOT/'contracts/control_implementation.json').read_text())
  self.assertEqual(c['request_bits'], {'ARM':0,'STOP':1,'SNAPSHOT':2})
  self.assertEqual(c['snapshot_status']['offset_hex'],'0x0210')
  sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/control/cdc_mailbox.sv','rtl/control/event_mailbox.sv','rtl/time/gsc_timebase.sv','rtl/control/csr_control_axi.sv','tb/unit/tb_control.sv']
  with tempfile.TemporaryDirectory() as tmp:
   image=pathlib.Path(tmp)/'control.vvp'
   build=subprocess.run([iv,'-g2012','-s','tb_control','-o',str(image),*[str(ROOT/p) for p in sources]],capture_output=True,text=True,timeout=60)
   self.assertEqual(build.returncode,0,build.stdout+build.stderr)
   run=subprocess.run([vv,str(image)],capture_output=True,text=True,timeout=60)
   (ROOT/'reports/control-simulation.log').write_text(build.stdout+build.stderr+run.stdout+run.stderr)
   self.assertEqual(run.returncode,0,run.stdout+run.stderr)
   self.assertIn('PASS control AXI CDC snapshot faults reset',run.stdout)
if __name__=='__main__':unittest.main()
