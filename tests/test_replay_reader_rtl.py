from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    out=ROOT/'reports/replay_reader.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_frozen_replay_reader','-o',str(out),str(ROOT/'rtl/replay/frozen_replay_reader.sv'),str(ROOT/'tb/unit/tb_frozen_replay_reader.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/'reports/replay_reader.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0,p.stdout+p.stderr
    assert 'PASS frozen replay reader' in p.stdout
    print(p.stdout)
if __name__=='__main__':run()
