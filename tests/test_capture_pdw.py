from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_capture_pdw_writer','-o',sim,'rtl/generated/capture_event_pkg.sv','rtl/capture/capture_pdw_writer.sv','tb/unit/tb_capture_pdw_writer.sv'],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True,timeout=60)
    (ROOT/'reports/capture_pdw.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS capture PDW' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
