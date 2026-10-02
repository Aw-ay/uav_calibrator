import pathlib,sys,struct,subprocess,tempfile,unittest,random
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import encode_frame
class RecordBridgeRTLTests(unittest.TestCase):
 def test_async_bridge(self):
  iv=pathlib.Path('C:/iverilog/bin/iverilog.exe');vv=iv.with_name('vvp.exe')
  sources=[ROOT/p for p in ['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/crc32c_parallel_pkg.sv','rtl/control/cdc_mailbox.sv','rtl/data/axis_record_fifo.sv','rtl/data/record_upload_path.sv','rtl/capture/b_port_reader_128.sv','rtl/capture/dma_payload_packer.sv','rtl/capture/record_formatter_128.sv','rtl/capture/record_dma_bridge.sv','tb/system/tb_record_bridge.sv']]
  self.assertTrue(all(p.exists() for p in sources),'record lease bridge implementation missing')
  with tempfile.TemporaryDirectory() as td:
   td=pathlib.Path(td);exe=td/'sim'
   c=subprocess.run([str(iv),'-g2012','-s','tb_record_bridge','-o',str(exe),*map(str,sources)],capture_output=True,text=True)
   self.assertEqual(c.returncode,0,c.stdout+c.stderr)
   rng=random.Random(812)
   mem=[tuple(rng.randrange(-32768,32768) for _ in range(4)) for _ in range(16384)]
   (td/'ram.hex').write_text('\n'.join((struct.pack('<hhhh',*mem[i])+struct.pack('<hhhh',*mem[i+1]))[::-1].hex() for i in range(0,16384,2)))
   cases=[(0,1,False,False,None),(1,2,True,True,None),(16383,17,False,True,None),(16383,16384,True,True,None),(0,2,False,True,0),(0,0,False,True,64),(0,16385,False,True,64)]
   cases += [(1,2,True,True,off) for off in [4,6,8,12,52,56,60,124]]
   cases += [(16383,16384,True,True,'fifo')]
   for start,n,trailer,crc,bad in cases:
    fifo=bad=='fifo'
    if fifo:
     bad=None
     c=subprocess.run([str(iv),'-g2012','-s','tb_record_bridge','-Ptb_record_bridge.USE_FIFO=1','-o',str(exe),*map(str,sources)],capture_output=True,text=True)
     self.assertEqual(c.returncode,0,c.stdout+c.stderr)
    frame=encode_frame({'format_id':7,'pulse_id':98765},[mem[(start+i)%16384] for i in range(n if bad is None else 2)],trailer=trailer,header_crc=crc)
    header=bytearray(frame[:128])
    if bad is not None:
     if bad in [52,56,60]:header[bad:bad+4]=bytes(4)
     else:header[bad]^=1
    (td/'header.hex').write_text(header[::-1].hex());(td/'expected.hex').write_text('\n'.join(f'{b:02x}' for b in frame))
    run=subprocess.run([str(vv),str(exe),f'+ROOT={td.as_posix()}',f'+START={start}',f'+COUNT={n}',f'+BYTES={len(frame)}',f'+REJECT={int(bad is not None)}'],capture_output=True,text=True)
    self.assertEqual(run.returncode,0,run.stdout+run.stderr);self.assertIn('PASS',run.stdout)
    print(f'case start={start} count={n} trailer={trailer} crc={crc} malformed={bad}: {run.stdout.strip()}')
if __name__=='__main__':unittest.main()
