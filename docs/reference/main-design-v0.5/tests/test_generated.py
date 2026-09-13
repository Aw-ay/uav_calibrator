from pathlib import Path
import json,unittest,subprocess,sys
R=Path(__file__).resolve().parents[1]
class Generated(unittest.TestCase):
    def test_constants_files_exist_and_match(self):
        self.assertTrue((R/'generated/calib_contract.h').exists(),'generate C/SV constants before delivery')
        self.assertTrue((R/'generated/calib_contract_pkg.sv').exists())
        r=subprocess.run([sys.executable,'tools/generate_contracts.py','--check'],cwd=R,capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    def test_bank_and_rate_constants(self):
        p=R/'generated/constants.json';self.assertTrue(p.exists())
        if p.exists():
            c=json.loads(p.read_text());self.assertEqual(c['BANK_COUNT_BITS'],15);self.assertEqual(c['DMA_CLOCK_HZ'],200000000)
            self.assertEqual(c['FIR_CLOCK_HZ'],125000000);self.assertEqual(c['MAX_RECORD_BYTES'],131216)
            self.assertEqual(c['RETURN_TOKEN_BYTES'],32);self.assertEqual(c['REPLAY_TASK_BYTES'],192)
if __name__=='__main__':unittest.main()
