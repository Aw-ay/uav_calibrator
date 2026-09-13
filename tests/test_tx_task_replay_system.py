from pathlib import Path
import subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 for cmd in [['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_tx_task_replay_system','-o',sim,*sources,'tb/system/tb_tx_task_replay_system.sv'],['C:/iverilog/bin/vvp.exe',sim]]:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=60)
  assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout)
 assert 'PASS shared lifecycle real replay system' in p.stdout
