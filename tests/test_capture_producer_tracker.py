from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/capture/capture_bank_manager.sv','rtl/capture/capture_producer_tracker.sv','tb/system/tb_capture_producer_tracker.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_capture_producer_tracker','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/capture_producer_tracker.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS capture producer tracker' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
