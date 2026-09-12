from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_range_statistics','-o',str(out),str(ROOT/'rtl/capture/pulse_range_statistics.sv'),str(ROOT/'tb/unit/tb_range_statistics.sv')],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/range_statistics.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS range statistics' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
