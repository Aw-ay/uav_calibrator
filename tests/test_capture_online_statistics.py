from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_capture_online_statistics','-o',sim]+[f'rtl/capture/{n}.sv' for n in ['receive_power_pipeline','online_body_statistics','capture_online_statistics']]+['tb/unit/tb_capture_online_statistics.sv'],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
