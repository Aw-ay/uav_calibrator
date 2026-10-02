from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 out=str(Path(tmp)/'sim')
 sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/aux_metadata_pkg.sv','rtl/capture/frame_header_builder.sv','rtl/capture/aux_record_metadata.sv','rtl/capture/aux_record_admission.sv','rtl/capture/capture_bank_manager.sv','rtl/capture/aux_window_tracker.sv','tb/system/tb_aux_record_pipeline.sv']
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_aux_record_pipeline','-o',out]+sources,cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS AUX_PIPELINE' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
