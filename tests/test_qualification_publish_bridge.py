from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    names=['capture_bank_manager','pulse_context_join','pulse_context_pool','noise_window_energy','range_linearity','capture_range_select','range_qualification','pulse_qualification_engine','qualification_bank_commit','qualification_publish_bridge']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_qualification_publish_bridge','-o',str(out),*[str(ROOT/f'rtl/capture/{n}.sv') for n in names],str(ROOT/'tb/system/tb_qualification_publish_bridge.sv')],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/qualification_publish_bridge.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS qualification publish bridge' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
