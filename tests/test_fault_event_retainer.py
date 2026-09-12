from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 out=str(Path(tmp)/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_fault_event_retainer','-o',out,'rtl/control/fault_event_retainer.sv','tb/unit/tb_fault_event_retainer.sv'],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 assert 'implicit definition' not in p.stderr,p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS fault event retainer' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
