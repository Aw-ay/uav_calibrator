import pathlib,sys,struct,subprocess,tempfile,unittest,random
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import encode_frame
class Record128RTLTests(unittest.TestCase):
 def test_reader_formatter_stream(self):
  iv=pathlib.Path('C:/iverilog/bin/iverilog.exe');vv=iv.with_name('vvp.exe')
  with tempfile.TemporaryDirectory() as td:
   td=pathlib.Path(td);exe=td/'sim'
   sources=[ROOT/'rtl/generated/calibrator_contract_pkg.sv',ROOT/'rtl/generated/crc32c_parallel_pkg.sv',ROOT/'rtl/capture/b_port_reader_128.sv',ROOT/'rtl/capture/dma_payload_packer.sv',ROOT/'rtl/capture/record_formatter_128.sv',ROOT/'tb/unit/tb_record_stream_128.sv']
   self.assertTrue(all(p.exists() for p in sources),'record RTL implementation missing')
   subprocess.run([str(iv),'-g2012','-s','tb_record_stream_128','-o',str(exe),*map(str,sources)],check=True,capture_output=True,text=True)
   rng=random.Random(703)
   mem=[tuple(rng.randrange(-32768,32768) for _ in range(4)) for _ in range(16384)]
   (td/'ram.hex').write_text('\n'.join((struct.pack('<hhhh',*mem[i])+struct.pack('<hhhh',*mem[i+1]))[::-1].hex() for i in range(0,16384,2)))
   cases=[(0,1),(1,1),(0,2),(1,2),(16383,3),(16382,4),(16383,16384),(17,17),(0,16384),(1,16383)]
   for start,n in cases:
    for trailer,crc in [(False,False),(False,True),(True,False),(True,True)]:
     frame=encode_frame({'format_id':7,'pulse_id':98765,'fraction_ticks_q16':-1234,'nco_frequency_hz':-777,'metadata_id':91},[mem[(start+i)%16384] for i in range(n)],trailer=trailer,header_crc=crc)
     header=bytearray(frame[:128]);header[112:116]=b'\xab'*4
     (td/'header.hex').write_text(header[::-1].hex())
     (td/'expected.hex').write_text('\n'.join(f'{b:02x}' for b in frame))
     run=subprocess.run([str(vv),str(exe),f'+ROOT={td.as_posix()}',f'+START={start}',f'+COUNT={n}',f'+BYTES={len(frame)}',f'+ALWAYS_READY={int(start==0 and n==16384)}'],capture_output=True,text=True)
     self.assertEqual(run.returncode,0,run.stdout+run.stderr);self.assertIn('PASS',run.stdout)
   for count,offset in [(0,None),(16385,None),(2,0),(2,4),(2,6),(2,8),(2,12),(2,64),(2,124),(2,52),(2,56),(2,60)]:
    header=bytearray(encode_frame({'format_id':7},mem[:2])[:128])
    if offset is not None:
     if offset in (52,56,60):header[offset:offset+4]=bytes(4)
     else:header[offset]^=1
    (td/'header.hex').write_text(header[::-1].hex())
    run=subprocess.run([str(vv),str(exe),f'+ROOT={td.as_posix()}','+START=0',f'+COUNT={count}','+BYTES=144','+REJECT=1'],capture_output=True,text=True)
    self.assertEqual(run.returncode,0,run.stdout+run.stderr);self.assertIn('PASS',run.stdout)
if __name__=='__main__':unittest.main()
