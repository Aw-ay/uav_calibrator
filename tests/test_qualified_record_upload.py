from pathlib import Path
import subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import encode_frame

def vectors():
    directory=ROOT/'build/qualified_upload_vectors';directory.mkdir(parents=True,exist_ok=True)
    frames=[encode_frame({'format_id':7,'stream_group_id':g+1,'pulse_id':100},[(s,g,s+1,-g) for s in range(16381,16388)],trailer=True) for g in range(3)]
    (directory/'headers.hex').write_text('\n'.join(f[:128][::-1].hex() for f in frames))
    (directory/'expected.hex').write_text('\n'.join(f'{b:02x}' for b in frames[1]))
    return directory

if __name__=='__main__':
    directory=vectors()
    sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/crc32c_parallel_pkg.sv','rtl/control/cdc_mailbox.sv']
    sources += ['rtl/capture/'+n+'.sv' for n in ['capture_bank_manager','capture_ram','capture_bank_array','b_port_reader_128','dma_payload_packer','record_formatter_128','record_dma_bridge','capture_record_system','pulse_context_join','pulse_context_pool','noise_window_energy','range_linearity','capture_range_select','range_qualification','pulse_qualification_engine','qualification_bank_commit','qualification_publish_bridge','qualification_record_source']]
    sources += ['rtl/data/'+n+'.sv' for n in ['axis_record_fifo','record_upload_path','record_descriptor_arbiter','record_upload_groups']]
    sources += ['tb/system/tb_qualified_record_upload.sv']
    with tempfile.TemporaryDirectory() as temp:
        sim=str(Path(temp)/'sim')
        p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_qualified_record_upload','-o',sim,*sources],cwd=ROOT,capture_output=True,text=True,timeout=60)
        assert p.returncode==0,p.stdout+p.stderr
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=60)
        (ROOT/'reports/qualified_record_upload.log').write_text(p.stdout+p.stderr)
        assert p.returncode==0 and 'PASS qualified record upload' in p.stdout,p.stdout+p.stderr
        print(p.stdout)
        p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_qualification_record_source','-o',sim,'rtl/capture/qualification_record_source.sv','tb/unit/tb_qualification_record_source.sv'],cwd=ROOT,capture_output=True,text=True,timeout=60)
        assert p.returncode==0,p.stdout+p.stderr
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True,timeout=60)
        (ROOT/'reports/qualification_record_source.log').write_text(p.stdout+p.stderr)
        assert p.returncode==0 and 'PASS qualification record source' in p.stdout,p.stdout+p.stderr
        print(p.stdout)
