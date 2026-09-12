from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_receive_event_producer','-o',out,'rtl/capture/pulse_detector.sv','rtl/capture/noise_snapshot.sv','rtl/capture/receive_event_producer.sv','tb/system/tb_receive_event_producer.sv'],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=30)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
