from pathlib import Path
import subprocess,sys,tempfile,shutil
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reports/instrument_stage21'
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources
s=(ROOT/'tb/system/tb_calibrator_instrument_core.sv').read_text()
changes=[('command(CMD_REPLAY,48,0);wait(dut.d_r_dsp_done||dut.d_r_rejected_valid);','command(CMD_REPLAY,48,0);wait(dut.dataplane.replay_active||dut.d_r_rejected_valid);command(CMD_STOP,0,0);'),('replay_samples!=snapshot[3342:3328]||!saw_dac','replay_samples!=0||saw_dac'),('retirement[96+:32]!=0','retirement[96+:32]!=1'),('PASS REPLAY_LIFECYCLE_CORE','PASS REPLAY_EARLY_CANCEL_CORE')]
for a,b in changes:
 assert a in s,a
 s=s.replace(a,b)
tb=OUT/'tb_core_early_cancel.sv';tb.write_text(s)
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);shutil.copyfile(ROOT/'build/capture_system_vectors/headers.hex',d/'headers.hex');sim=d/'sim'
 commands=[['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_calibrator_instrument_core','-o',str(sim),*sources,str(tb)],['C:/iverilog/bin/vvp.exe',str(sim),'+ROOT='+d.as_posix()]]
 for cmd in commands:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=240)
  if(cmd[0].endswith('vvp.exe')):(OUT/'early_cancel.log').write_text(p.stdout+p.stderr)
  assert p.returncode==0,p.stdout+p.stderr
 assert 'PASS REPLAY_EARLY_CANCEL_CORE' in p.stdout
 print('PASS instrument early replay cancellation: zero RAW replay samples, bank returned, identity then STOP retirement, events retained after reset')
