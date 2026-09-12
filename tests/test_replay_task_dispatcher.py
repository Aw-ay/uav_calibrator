from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/replay/replay_control_layout_pkg.sv','rtl/replay/replay_descriptor_queue.sv','rtl/replay/replay_legality_checker.sv','rtl/replay/frozen_replay_reader.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv','rtl/replay/replay_task_dispatcher.sv','tb/system/tb_replay_task_dispatcher.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_replay_task_dispatcher','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/replay_task_dispatcher.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS replay task dispatcher' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
