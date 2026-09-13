from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/fault_event_pkg.sv','rtl/control/fault_event_encoder.sv','rtl/control/fault_event_retainer.sv','rtl/control/event_priority_arbiter.sv','rtl/control/cdc_mailbox.sv','rtl/control/event_mailbox.sv','rtl/control/fault_event_transport.sv','rtl/time/gsc_timebase.sv','rtl/control/csr_control_axi.sv','tb/system/tb_unified_event_axi.sv']
with tempfile.TemporaryDirectory() as tmp:
 sim=Path(tmp)/'sim'
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_unified_event_axi','-o',str(sim),*SOURCES],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 assert not any(s in p.stderr for s in ['not found','dangling input','implicit definition']),p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(sim)],cwd=ROOT,capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and 'PASS unified EVENT AXI' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
