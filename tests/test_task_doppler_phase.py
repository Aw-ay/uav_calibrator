from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_task_doppler_phase','-o',out,
        'rtl/replay/task_doppler_phase.sv','tb/system/tb_task_doppler_phase.sv'],cwd=ROOT,check=True)
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=30)
    assert p.returncode==0 and 'PASS task Doppler GSC phase' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
