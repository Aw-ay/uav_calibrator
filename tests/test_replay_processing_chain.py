from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 sources=['rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/rx_cal_executor.sv','rtl/arithmetic/target_complex_operator.sv','rtl/replay/replay_processing_chain.sv','tb/system/tb_replay_processing_chain.sv']
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_replay_processing_chain','-o',sim,*sources],cwd=ROOT,capture_output=True,text=True,timeout=60)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True,timeout=60)
 (ROOT/'reports/replay_processing_chain.log').write_text(p.stdout+p.stderr)
 assert p.returncode==0 and 'PASS replay processing chain' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
