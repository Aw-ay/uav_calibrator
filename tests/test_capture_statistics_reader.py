from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/capture/capture_bank_manager.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_statistics_reader.sv','tb/system/tb_capture_statistics_reader.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_capture_statistics_reader','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/capture_statistics_reader.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS capture statistics reader' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
