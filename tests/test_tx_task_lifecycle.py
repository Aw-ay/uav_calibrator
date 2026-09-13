from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reports/module_stage20';OUT.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 src=['rtl/replay/replay_control_layout_pkg.sv','rtl/generated/replay_identity_event_pkg.sv','rtl/generated/tx_lifecycle_event_pkg.sv','rtl/replay/replay_identity_event.sv','rtl/replay/replay_drain_observer.sv','rtl/control/tx_lifecycle_tracker.sv','rtl/control/event_priority_arbiter.sv','rtl/control/tx_task_lifecycle.sv','tb/unit/tb_tx_task_lifecycle.sv']
 for cmd in [['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_tx_task_lifecycle','-o',sim,*src],['C:/iverilog/bin/vvp.exe',sim,'+OUT='+(OUT/'rtl_records.txt').as_posix()]]:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=30);assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout);assert 'PASS shared TX lifecycle' in p.stdout
