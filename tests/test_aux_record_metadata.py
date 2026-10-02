from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 out=str(Path(tmp)/'sim')
 sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/aux_metadata_pkg.sv','rtl/capture/frame_header_builder.sv','rtl/capture/aux_record_metadata.sv','tb/system/tb_aux_record_metadata.sv']
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_aux_record_metadata','-o',out]+sources,cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',out,'+VECTOR=reports/aux_metadata_vector.txt'],cwd=ROOT,capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS AUX_METADATA' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
