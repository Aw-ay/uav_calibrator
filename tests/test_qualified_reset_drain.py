from pathlib import Path
import subprocess,tempfile
from test_qualified_record_upload import vectors
ROOT=Path(__file__).resolve().parents[1]
directory=vectors()
sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/control/cdc_mailbox.sv']
sources += ['rtl/capture/'+n+'.sv' for n in ['capture_bank_manager','capture_ram','capture_bank_array','frozen_record_reader','record_formatter','record_dma_bridge','capture_record_system','pulse_context_join','pulse_context_pool','noise_window_energy','range_linearity','capture_range_select','range_qualification','pulse_qualification_engine','qualification_bank_commit','qualification_publish_bridge','qualification_record_source','capture_reset_coordinator']]
sources += ['rtl/data/'+n+'.sv' for n in ['axis_record_fifo','record_upload_path','record_descriptor_arbiter','record_upload_groups']]
with tempfile.TemporaryDirectory() as tmp:
    for top,bench in [('tb_capture_reset_coordinator','tb/unit/tb_capture_reset_coordinator.sv'),('tb_qualified_reset_drain','tb/system/tb_qualified_reset_drain.sv')]:
        sim=str(Path(tmp)/top)
        p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',top,'-o',sim,*sources,bench],cwd=ROOT,capture_output=True,text=True,timeout=60)
        assert p.returncode==0,p.stdout+p.stderr
        for mode in ((0,1) if top=='tb_qualified_reset_drain' else (0,)):
            p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}',f'+PULSE_REQUEST={mode}'],cwd=ROOT,capture_output=True,text=True,timeout=60)
            (ROOT/f'reports/{top}_{mode}.log').write_text(p.stdout+p.stderr)
            assert p.returncode==0 and 'PASS ' in p.stdout,p.stdout+p.stderr
            print(p.stdout)
