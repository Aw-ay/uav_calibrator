import pathlib,sys,struct,unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from frame_codec import encode_frame,decode_frame,crc32c
class CodecTests(unittest.TestCase):
 def test_zero_sample_rate_encoder(self):
  with self.assertRaises(ValueError):encode_frame({'format_id':7,'sample_rate_num':0},[(1,2,3,4)])
 def test_zero_sample_rate_decoder_with_valid_crc(self):
  b=bytearray(encode_frame({'format_id':7},[(1,2,3,4)]))
  struct.pack_into('<I',b,56,0)
  struct.pack_into('<I',b,112,0)
  struct.pack_into('<I',b,112,crc32c(b[:128]))
  with self.assertRaises(ValueError):decode_frame(b)
 def test_crc_vector(self):self.assertEqual(crc32c(b'123456789'),0xe3069283)
 def test_boundaries_signed_odd_and_trailer(self):
  for n in [1,3,16384]:
   for trailer in [False,True]:
    iq=[(-32768,32767,-1,0)]*n;b=encode_frame({'format_id':7,'fraction_ticks_q16':-65536,'nco_frequency_hz':-1000},iq,trailer=trailer)
    h,s=decode_frame(b);self.assertEqual(s,iq);self.assertEqual(h['fraction_ticks_q16'],-65536);self.assertEqual(len(b),128+8*n+16*trailer)
 def test_corruption(self):
  b=encode_frame({'format_id':7},[(1,2,3,4)],trailer=True)
  for offset in [0,4,6,8,12,32,64,112,124,128,136,140,144,148]:
   bad=bytearray(b);bad[offset]^=1
   with self.assertRaises(ValueError,msg=str(offset)):decode_frame(bad)
  for bad in [b[:100],b[:-1],b+b'\0']:
   with self.assertRaises(ValueError):decode_frame(bad)
 def test_invalid_input(self):
  for samples in [[],[(32768,0,0,0)],[(1,2,3)],[(0,0,0,0)]*16385]:
   with self.assertRaises(ValueError):encode_frame({'format_id':7},samples)
  with self.assertRaises(ValueError):encode_frame({},[(0,0,0,0)])
 def test_disabled_crc_explicit(self):
  b=encode_frame({'format_id':7},[(0,0,0,0)],header_crc=False)
  h,_=decode_frame(b);self.assertTrue(h['quality_flags']&2);self.assertEqual(h['header_crc32c'],0)
if __name__=='__main__':unittest.main()
