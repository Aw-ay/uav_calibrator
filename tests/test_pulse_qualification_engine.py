from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['pulse_context_join','pulse_context_pool','noise_window_energy','range_linearity','capture_range_select','range_qualification','pulse_qualification_engine']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_pulse_qualification_engine','-o',str(out),*[str(ROOT/f'rtl/capture/{s}.sv') for s in sources],str(ROOT/'tb/system/tb_pulse_qualification_engine.sv')],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/pulse_qualification_engine.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS qualification engine' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
