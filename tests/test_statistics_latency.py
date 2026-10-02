from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_statistics_latency','-o',out,
        'rtl/capture/capture_statistics_reader.sv','tb/system/tb_statistics_latency.sv'],cwd=ROOT,check=True)
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0 and 'PASS statistics measured latency' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
