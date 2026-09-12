from pathlib import Path
import subprocess,tempfile,runpy
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 root=Path(tmp);runpy.run_path(str(ROOT/'tools/generate_fault_event_contract.py'))['generate'](root)
 for p in root.rglob('*'):
  if p.is_file():assert p.read_bytes()==(ROOT/p.relative_to(root)).read_bytes(),p
 out=str(root/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fault_event_encoder','-o',out,'rtl/generated/fault_event_pkg.sv','rtl/control/fault_event_encoder.sv','tb/unit/tb_fault_event_encoder.sv'],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0 and 'PASS fault event encoder' in p.stdout,p.stdout+p.stderr
 print('PASS generated SV/C/MATLAB/document ABI consistency');print(p.stdout)
