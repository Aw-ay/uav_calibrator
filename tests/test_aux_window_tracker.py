from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_aux_window_tracker','-o',out,'rtl/capture/capture_bank_manager.sv','rtl/capture/aux_window_tracker.sv','tb/system/tb_aux_window_tracker.sv'],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=60)
    (ROOT/'reports/aux_window_tracker.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS AUX_WINDOW' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
