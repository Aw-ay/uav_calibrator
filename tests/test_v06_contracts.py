from pathlib import Path
import hashlib,importlib.util,json,struct,subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[1]
class V06Contracts(unittest.TestCase):
 def test_package_and_local_compatibility(self):
  pkg=ROOT/'docs/releases/v0.6_DRFM_FINE_DMA'
  for name,sha in json.loads((pkg/'SHA256SUMS.json').read_text(encoding='utf-8'))['files'].items():
   self.assertEqual(hashlib.sha256((pkg/name).read_bytes()).hexdigest(),sha,name)
  ctl=json.loads((ROOT/'contracts/instrument_control.json').read_text())['commands']
  self.assertEqual([ctl[k]['opcode'] for k in ('AUX_CAPTURE','AUX_META_PEEK','AUX_META_POP')],[22,23,24])
  tr=json.loads((ROOT/'contracts/fine_result_transport.json').read_text())
  self.assertEqual(tr['schema_version'],2)
  self.assertEqual([v['opcode'] for v in tr['commands'].values()],[25,26])
  self.assertEqual([ctl[k]['opcode'] for k in ('FINE_PDW_PEEK','FINE_PDW_POP')],[25,26])
  self.assertEqual(len(set(v['opcode'] for v in ctl.values())),len(ctl))
  irq=json.loads((ROOT/'contracts/command_gateway.json').read_text())['irq_bits']
  self.assertEqual(irq['FINE_PDW_AVAILABLE'],32)
  self.assertEqual(len(set(irq.values())),len(irq))
  task=json.loads((ROOT/'contracts/replay_contract.json').read_text())['replay_task']['fields']
  self.assertTrue(any(f['name']=='doppler_step_q48' and f['offset_bytes']==136 for f in task))
 def test_generated_layout_and_signed_decode(self):
  spec=importlib.util.spec_from_file_location('fine_codec',ROOT/'tools/fine_pdw_codec.py')
  mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
  b=bytearray(128);struct.pack_into('<I',b,0,0x40001)
  struct.pack_into('<Q',b,8,0xfedcba9876543210)
  struct.pack_into('<i',b,80,-12345);struct.pack_into('<q',b,88,-9000000000000)
  struct.pack_into('<i',b,104,-536870912)
  d=mod.decode(b)
  self.assertEqual(d['pulse_id'],0xfedcba9876543210)
  self.assertEqual(d['h_residual_frequency_hz'],-12345)
  self.assertEqual(d['h_chirp_rate_hz_per_s'],-9000000000000)
  self.assertEqual(d['hv_phase_q31_turn'],-536870912)
  for invalid in (b[:-1],bytes(128),bytes(b[:124])+b'\x01\0\0\0'):
   with self.assertRaises(ValueError):mod.decode(invalid)
  subprocess.run([sys.executable,str(ROOT/'tools/generate_fine_layout.py'),'--check'],check=True)
if __name__=='__main__':unittest.main()
