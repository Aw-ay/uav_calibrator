from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_event_mailbox','-o',sim,'rtl/control/cdc_mailbox.sv','rtl/control/event_mailbox.sv','tb/unit/tb_event_mailbox.sv'],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True,timeout=60)
    (ROOT/'reports/event_mailbox.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS event mailbox' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
