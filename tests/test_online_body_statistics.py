from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
def run():
 logs=[]
 for hold,length in ((1,1),(1,3),(125,4),(125,27),(256,15500),(256,16384)):
  expected=[]
  for slot in range(4):
   begin=20+slot*3
   powers=[tuple(2**31 if n%71==0 else (n%37+c*3)**2 for c in range(6)) for n in range(begin,begin+length)]
   energy=[sum(p[c] for p in powers) for c in range(6)]
   peak=[max(p[c] for p in powers) for c in range(6)]
   top=[]
   for c in range(6):
    net=[max(p[c]-10*c,0) for p in powers]
    top.append(max((sum(net[i:i+4])//4 for i in range(len(net)-3)),default=0))
   value=sum(v<<(46*c) for c,v in enumerate(energy))
   value|=sum(v<<(276+32*c) for c,v in enumerate(peak))
   value|=sum(v<<(468+32*c) for c,v in enumerate(top))
   value|=length<<660
   value|=(int(begin<=35<begin+length))<<675
   expected.append(f'{value:0173x}')
  with tempfile.TemporaryDirectory() as tmp:
   td=Path(tmp);(td/'online_expected.hex').write_text('\n'.join(expected));sim=td/'sim'
   p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_online_body_statistics',f'-Ptb_online_body_statistics.HOLD={hold}',f'-Ptb_online_body_statistics.LENGTH={length}','-o',str(sim),str(ROOT/'rtl/capture/online_body_statistics.sv'),str(ROOT/'tb/unit/tb_online_body_statistics.sv')],capture_output=True,text=True)
   assert p.returncode==0,p.stdout+p.stderr
   p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(sim),f'+ROOT={td.as_posix()}'],capture_output=True,text=True)
   logs.append(p.stdout+p.stderr);(ROOT/'reports/v06_online_body_statistics.log').write_text('\n'.join(logs))
   assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 with tempfile.TemporaryDirectory() as tmp:
  sim=Path(tmp)/'errors'
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_online_body_statistics_errors','-o',str(sim),str(ROOT/'rtl/capture/online_body_statistics.sv'),str(ROOT/'tb/unit/tb_online_body_statistics_errors.sv')],capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(sim)],capture_output=True,text=True)
  logs.append(p.stdout+p.stderr);(ROOT/'reports/v06_online_body_statistics.log').write_text('\n'.join(logs))
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 print('\n'.join(logs))
if __name__=='__main__':run()
