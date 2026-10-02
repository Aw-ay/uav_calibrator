from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
logs=[]
for hold,length in ((1,1),(1,3),(125,4),(0,27),(256,27),(256,14999)):
 with tempfile.TemporaryDirectory() as tmp:
  sim=str(Path(tmp)/'sim')
  sources=['pulse_detector','noise_snapshot','receive_event_producer','receive_power_pipeline','online_body_statistics']
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_receive_online_statistics',f'-Ptb_receive_online_statistics.HOLD={hold}',f'-Ptb_receive_online_statistics.LENGTH={length}','-o',sim]+[f'rtl/capture/{s}.sv' for s in sources]+['tb/system/tb_receive_online_statistics.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True,timeout=60)
  logs.append(p.stdout+p.stderr)
  (ROOT/'reports/v06_receive_online_statistics.log').write_text(''.join(logs))
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
print(''.join(logs))
