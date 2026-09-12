from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/generated/fault_event_pkg.sv','rtl/control/fault_event_encoder.sv','rtl/control/fault_event_retainer.sv','rtl/control/event_priority_arbiter.sv','rtl/control/cdc_mailbox.sv','rtl/control/event_mailbox.sv','rtl/control/fault_event_transport.sv','tb/system/tb_fault_event_transport.sv']
with tempfile.TemporaryDirectory() as tmp:
 out=str(Path(tmp)/'sim');records=ROOT/'reports/module_stage11/rtl_records.txt';records.parent.mkdir(exist_ok=True)
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_fault_event_transport','-o',out,*SOURCES],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 assert not any(s in p.stderr for s in ['implicit definition','dangling input','expects']),p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',out,'+OUT='+records.as_posix()],cwd=ROOT,capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS fault event transport' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
