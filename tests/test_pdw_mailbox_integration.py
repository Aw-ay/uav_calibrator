from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/generated/capture_event_pkg.sv','rtl/control/cdc_mailbox.sv','rtl/control/event_mailbox.sv','rtl/capture/capture_pdw_writer.sv','tb/system/tb_pdw_mailbox_integration.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_pdw_mailbox_integration','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/pdw_mailbox_integration.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS PDW mailbox integration' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
