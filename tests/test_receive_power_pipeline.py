from pathlib import Path
import random,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(6801)
with tempfile.TemporaryDirectory() as tmp:
 td=Path(tmp);rows=[]
 for n in range(256):
  iq=[rng.randrange(-32768,32768) for _ in range(16)]
  if n==0:iq=[-32768]*16
  data=sum((x&65535)<<(16*i) for i,x in enumerate(iq))
  powers=[iq[(c%3)*4+(c//3)*2]**2+iq[(c%3)*4+(c//3)*2+1]**2 for c in range(6)]
  rows.append(f'{data+sum(v<<(256+32*c) for c,v in enumerate(powers)):0112x}')
 (td/'power.hex').write_text('\n'.join(rows))
 sim=str(td/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_receive_power_pipeline','-o',sim,'rtl/capture/receive_power_pipeline.sv','tb/unit/tb_receive_power_pipeline.sv'],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}'],capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
