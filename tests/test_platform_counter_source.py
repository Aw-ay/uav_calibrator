from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 out=str(Path(tmp)/'sim')
 for args in [['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_platform_counter_source','-o',out,'rtl/platform/platform_counter_source.sv','tb/system/tb_platform_counter_source.sv'],['C:/iverilog/bin/vvp.exe',out]]:
  p=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=30);assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout)
