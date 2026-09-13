from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/module_stage19';OUT.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 for cmd in [['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_replay_identity_event','-o',sim,'rtl/replay/replay_control_layout_pkg.sv','rtl/generated/replay_identity_event_pkg.sv','rtl/replay/replay_identity_event.sv','tb/unit/tb_replay_identity_event.sv'],['C:/iverilog/bin/vvp.exe',sim,'+OUT='+(OUT/'rtl_records.txt').as_posix()]]:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=30)
  assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout)
 assert 'PASS replay identity event' in p.stdout
