from pathlib import Path
import subprocess,tempfile,runpy
ROOT=Path(__file__).resolve().parents[1]
render=runpy.run_path(str(ROOT/'tools/generate_replay_control_layout.py'))['render']
assert (ROOT/'rtl/replay/replay_control_layout_pkg.sv').read_text()==render(), 'replay ABI drift'
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/replay/replay_control_layout_pkg.sv','rtl/replay/replay_descriptor_queue.sv','rtl/replay/replay_legality_checker.sv','tb/unit/tb_replay_control.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_replay_control','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/replay_control.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS replay control' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
