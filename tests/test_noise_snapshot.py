from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/capture/noise_snapshot.sv','rtl/capture/noise_window_energy.sv','tb/unit/tb_noise_snapshot.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_noise_snapshot','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/noise_snapshot.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS noise snapshot' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
