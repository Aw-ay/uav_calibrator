from pathlib import Path
import subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_capture_system import vectors
sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/capture_event_pkg.sv','rtl/replay/replay_control_layout_pkg.sv']
sources += ['rtl/generated/replay_identity_event_pkg.sv','rtl/generated/tx_lifecycle_event_pkg.sv','rtl/generated/fault_event_pkg.sv','rtl/generated/command_gateway_pkg.sv','rtl/generated/instrument_control_pkg.sv']
sources += [str(p.relative_to(ROOT)) for p in (ROOT/'rtl').rglob('*.sv') if str(p.relative_to(ROOT)).replace('\\','/') not in sources and not p.name.endswith('_pkg.sv')]
if __name__=='__main__':
    directory=vectors()
    with tempfile.TemporaryDirectory() as tmp:
        sim=str(Path(tmp)/'sim')
        p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_dataplane_system','-o',sim,*sources,'tb/system/tb_calibrator_dataplane_system.sv'],cwd=ROOT,capture_output=True,text=True,timeout=120)
        assert p.returncode==0,p.stdout+p.stderr
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=120)
        (ROOT/'reports/calibrator_dataplane_system.log').write_text(p.stdout+p.stderr)
        assert p.returncode==0 and 'PASS integrated dataplane' in p.stdout,p.stdout+p.stderr
        print(p.stdout)
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}','+CANCEL_ONLY'],cwd=ROOT,capture_output=True,text=True,timeout=120)
        (ROOT/'reports/calibrator_dataplane_cancel.log').write_text(p.stdout+p.stderr)
        assert p.returncode==0 and 'PASS integrated dataplane soft reset' in p.stdout,p.stdout+p.stderr
        print(p.stdout)
