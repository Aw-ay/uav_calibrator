from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_bank_ownership','-o',sim,'rtl/capture/capture_bank_manager.sv','tb/unit/tb_fine_bank_ownership.sv'],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 (ROOT/'reports/v06_fine_bank_ownership.log').write_text(p.stdout+p.stderr);print(p.stdout)
