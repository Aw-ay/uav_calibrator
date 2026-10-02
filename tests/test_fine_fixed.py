import math,random,sys,unittest,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from fine_fixed import cordic_phase_q31,ATAN_Q31
class TestFineFixed(unittest.TestCase):
 def test_quadrants_extrema_random(self):
  rng=random.Random(7006)
  values=[(1,0),(0,1),(-1,0),(0,-1),(-(1<<47),-(1<<47)),((1<<47)-1,-(1<<47))]
  values += [(rng.randrange(-(1<<47),1<<47),rng.randrange(-(1<<47),1<<47)) for _ in range(2000)]
  worst=0
  for x,y in values:
   got=cordic_phase_q31(x,y);expected=round(math.atan2(y,x)/(2*math.pi)*(1<<31))
   error=abs((got-expected+(1<<30))%(1<<31)-(1<<30));worst=max(worst,error)
   self.assertLessEqual(error,8,(x,y,got,expected))
  print('CORDIC maximum phase error',worst,'Q31-turn LSB')
 def test_contract_rom(self):
  contract=json.loads((Path(__file__).resolve().parents[1]/'contracts/fine_numeric.json').read_text())
  self.assertEqual(list(ATAN_Q31),contract['phase']['atan_table_q31'])
 def test_invalid(self):
  with self.assertRaises(ValueError):cordic_phase_q31(0,0)
  with self.assertRaises(OverflowError):cordic_phase_q31(1<<47,0)
if __name__=='__main__':unittest.main(verbosity=2)
