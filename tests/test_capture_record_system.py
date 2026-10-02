from pathlib import Path
import subprocess, tempfile, unittest, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from frame_codec import encode_frame

class CaptureRecordSystemTests(unittest.TestCase):
 def test_real_capture_upload(self):
  with tempfile.TemporaryDirectory() as directory:
   temp=Path(directory)
   frames=[]
   # Independent stimulus oracle: each group writes (seq, group, seq+1, -group).
   for group in range(4):
    frames.append(encode_frame({'format_id':7,'stream_group_id':group+1,'pulse_id':100+group},
      [(seq,group,seq+1,-group) for seq in range(16381,16388)],trailer=True))
   frames.append(encode_frame({'format_id':7,'stream_group_id':4,'pulse_id':200},
      [(seq,3,seq+1,-3) for seq in range(16401,16408)],trailer=True))
   frames.append(encode_frame({'format_id':7,'stream_group_id':1,'pulse_id':300},
      [(seq,0,seq+1,0) for seq in range(16421,16428)],trailer=True))
   (temp/'headers.hex').write_text('\n'.join(frame[:128][::-1].hex() for frame in frames))
   expected=b''.join(frames)
   (temp/'expected.hex').write_text('\n'.join(f'{byte:02x}' for byte in expected))
   sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/crc32c_parallel_pkg.sv','rtl/control/cdc_mailbox.sv',
    'rtl/capture/capture_bank_manager.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv',
    'rtl/capture/b_port_reader_128.sv','rtl/capture/dma_payload_packer.sv','rtl/capture/record_formatter_128.sv','rtl/capture/record_dma_bridge.sv',
    'rtl/data/axis_record_fifo.sv','rtl/data/record_upload_path.sv','rtl/data/record_descriptor_arbiter.sv',
    'rtl/data/record_upload_groups.sv','rtl/capture/capture_record_system.sv','tb/system/tb_capture_record_system.sv']
   run=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_capture_record_system','-o',str(temp/'sim'),
                       *[str(ROOT/source) for source in sources]],capture_output=True,text=True)
   self.assertEqual(run.returncode,0,run.stdout+run.stderr)
   for early_reset in (0,1):
    run=subprocess.run(['C:/iverilog/bin/vvp.exe',str(temp/'sim'),f'+ROOT={temp.as_posix()}',f'+BYTES={len(expected)}',f'+EARLY_RESET={early_reset}'],capture_output=True,text=True)
    (ROOT/f'reports/capture_record_system_reset_{early_reset}.log').write_text(run.stdout+run.stderr)
    self.assertEqual(run.returncode,0,run.stdout+run.stderr)
    self.assertIn('PASS capture record system',run.stdout)
if __name__=='__main__':unittest.main()
