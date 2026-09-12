from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim'
    src=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/capture_event_pkg.sv','rtl/capture/capture_pdw_writer.sv','rtl/control/qualified_pdw_queue.sv','tb/unit/tb_qualified_pdw_queue.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_qualified_pdw_queue','-o',str(out),*src],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],cwd=ROOT,capture_output=True,text=True,timeout=30)
    (ROOT/'reports/qualified_pdw_queue.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS qualified PDW queue' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
