from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/control/rf_safety_interlock.sv','rtl/control/aux_source_controller.sv','tb/unit/tb_rf_control.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_rf_control','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/rf_control.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS RF control' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
