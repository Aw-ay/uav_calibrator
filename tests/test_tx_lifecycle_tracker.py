from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/module_stage16';OUT.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
 sim=Path(tmp)/'sim'
 for cmd in [['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_tx_lifecycle_tracker','-o',str(sim),'rtl/generated/tx_lifecycle_event_pkg.sv','rtl/control/tx_lifecycle_tracker.sv','tb/unit/tb_tx_lifecycle_tracker.sv'],['C:/iverilog/bin/vvp.exe',str(sim),'+OUT='+(OUT/'rtl_records.txt').as_posix()]]:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=30);assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout)
 assert 'PASS TX lifecycle tracker' in p.stdout
