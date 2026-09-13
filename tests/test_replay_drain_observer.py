from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 for cmd in [['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_replay_drain_observer','-o',sim,'rtl/replay/replay_drain_observer.sv','tb/unit/tb_replay_drain_observer.sv'],['C:/iverilog/bin/vvp.exe',sim]]:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=30)
  assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout)
 assert 'PASS replay drain observer' in p.stdout
