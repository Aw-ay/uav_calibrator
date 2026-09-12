from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/capture/pulse_context_join.sv','rtl/capture/pulse_context_pool.sv','tb/unit/tb_pulse_context_pool.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_pulse_context_pool','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/pulse_context_pool.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS pulse context pool' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
