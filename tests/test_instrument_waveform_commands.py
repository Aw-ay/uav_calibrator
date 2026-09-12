from pathlib import Path
import subprocess,tempfile,sys,re,struct
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources,vectors
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import decode_frame
directory=vectors()
with tempfile.TemporaryDirectory() as tmp:
    sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_instrument_waveform_commands','-o',sim,*sources,'tb/system/tb_instrument_waveform_commands.sv'],cwd=ROOT,capture_output=True,text=True,timeout=120)
    assert p.returncode==0,p.stdout+p.stderr
    assert not any(term in p.stderr for term in ['implicit definition','dangling input','expects']),p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=240)
    (ROOT/'reports/instrument_waveform_commands.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS instrument waveform commands' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
