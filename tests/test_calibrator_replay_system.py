from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/replay/replay_control_layout_pkg.sv','rtl/replay/replay_descriptor_queue.sv','rtl/replay/replay_legality_checker.sv','rtl/replay/frozen_replay_reader.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv','rtl/replay/replay_task_dispatcher.sv','rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/rx_cal_executor.sv','rtl/arithmetic/fractional_delay_pipelined.sv','rtl/arithmetic/fractional_delay_profile.sv','rtl/generated/fractional_delay_coeff_rom.sv','rtl/arithmetic/target_complex_operator.sv','rtl/replay/replay_processing_chain.sv','rtl/replay/calibrator_replay_system.sv','tb/system/tb_calibrator_replay_system.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_replay_system','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/calibrator_replay_system.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS calibrator replay system' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
