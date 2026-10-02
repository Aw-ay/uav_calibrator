from pathlib import Path
import subprocess,tempfile,unittest,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import encode_frame
class RecordGroupsTests(unittest.TestCase):
 def test_four_groups(self):
  with tempfile.TemporaryDirectory() as temp:
   temp=Path(temp);frames=[]
   for group in range(4):
    index=group*4+(3-group)
    frames.append(encode_frame({'format_id':7,'stream_group_id':group+1,'pulse_id':100+group},[(index,1,2,3),(index,4,5,6)],trailer=True))
   (temp/'headers.hex').write_text('\n'.join(f[:128][::-1].hex() for f in frames))
   expected=b''.join(frames)
   (temp/'expected.hex').write_text('\n'.join(f'{v:02x}' for v in expected))
   sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/crc32c_parallel_pkg.sv','rtl/control/cdc_mailbox.sv','rtl/capture/b_port_reader_128.sv','rtl/capture/dma_payload_packer.sv','rtl/capture/record_formatter_128.sv','rtl/capture/record_dma_bridge.sv','rtl/data/axis_record_fifo.sv','rtl/data/record_upload_path.sv','rtl/data/record_descriptor_arbiter.sv','rtl/data/record_upload_groups.sv','tb/system/tb_record_upload_groups.sv']
   run=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_record_upload_groups','-o',str(temp/'sim'),*[str(ROOT/s) for s in sources]],capture_output=True,text=True)
   self.assertEqual(run.returncode,0,run.stdout+run.stderr)
   run=subprocess.run(['C:/iverilog/bin/vvp.exe',str(temp/'sim'),f'+ROOT={temp.as_posix()}',f'+BYTES={len(expected)}'],capture_output=True,text=True)
   self.assertEqual(run.returncode,0,run.stdout+run.stderr);self.assertIn('PASS',run.stdout)
if __name__=='__main__':unittest.main()
