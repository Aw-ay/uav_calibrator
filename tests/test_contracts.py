import copy, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
import generate_contracts as g
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ContractTests(unittest.TestCase):
 def test_baseline_and_determinism(self):
  c=g.load_contracts(ROOT/'contracts'); g.validate(c)
  with tempfile.TemporaryDirectory() as d:
   g.generate(c,pathlib.Path(d)); first={str(p.relative_to(d)):p.read_bytes() for p in pathlib.Path(d).rglob('*') if p.is_file()}
   g.generate(c,pathlib.Path(d)); self.assertEqual(first,{str(p.relative_to(d)):p.read_bytes() for p in pathlib.Path(d).rglob('*') if p.is_file()})
   for name,s in c['fir_coefficients']['stages'].items():
    data=(pathlib.Path(d)/'hw/coefficients'/f'{name}.coe').read_text().split('coefdata=')[1].strip().rstrip(';')
    self.assertEqual([int(x) for x in data.split(',')],s['integers'])
 def test_reject_overlap(self):
  for contract,key in [('register_map','registers'),('frame_format','header')]:
   c=g.load_contracts(ROOT/'contracts'); a=c[contract][key]; a[1]['offset_hex' if key=='registers' else 'offset_bytes']=a[0]['offset_hex' if key=='registers' else 'offset_bytes']
   with self.assertRaises(ValueError):g.validate(c)
 def test_reject_coefficient_overflow_and_abi(self):
  c=g.load_contracts(ROOT/'contracts'); c['fir_coefficients']['stages']['RX_HB19_D2']['integers'][0]=131072
  with self.assertRaises(ValueError):g.validate(c)
  c=g.load_contracts(ROOT/'contracts');c['frame_format']['abi_version']=4
  with self.assertRaises(ValueError):g.validate(c)
if __name__=='__main__': unittest.main()

class AdditionalContractTests(unittest.TestCase):
 def test_snapshot_region_bounds(self):
  for key,value in [('base_hex','0x10000'),('base_hex','-0x1000'),('base_hex','0x3001'),('stride_bytes',0),('stride_bytes',-64),('stride_bytes',65),('rows',0),('rows',-1),('rows',1024)]:
   with self.subTest(key=key,value=value):
    c=g.load_contracts(ROOT/'contracts');c['register_map']['bank_snapshot_table'][key]=value
    with self.assertRaises(ValueError):g.validate(c)
 def test_reserved_region_bounds(self):
  for region in ['0x10000-0x10003','0x10004-0x10000','0x10001-0x10002']:
   with self.subTest(region=region):
    c=g.load_contracts(ROOT/'contracts');c['register_map']['reserved_groups'][region]='invalid test region'
    with self.assertRaises(ValueError):g.validate(c)
 def test_address_overlap(self):
  c=g.load_contracts(ROOT/'contracts');c['address_map']['segments'][1]['base_hex']=c['address_map']['segments'][0]['base_hex']
  with self.assertRaises(ValueError):g.validate(c)
 def test_reserved_register_collision(self):
  c=g.load_contracts(ROOT/'contracts');c['register_map']['registers'][0]['offset_hex']='0x0500'
  with self.assertRaises(ValueError):g.validate(c)
 def test_header_width(self):
  c=g.load_contracts(ROOT/'contracts');c['frame_format']['header'][0]['type']='u64'
  with self.assertRaises(ValueError):g.validate(c)
