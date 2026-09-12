from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['capture_bank_manager','qualification_bank_commit']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_qualification_bank_commit','-o',str(out),*[str(ROOT/f'rtl/capture/{s}.sv') for s in sources],str(ROOT/'tb/system/tb_qualification_bank_commit.sv')],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/qualification_bank_commit.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS qualification bank commit' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
