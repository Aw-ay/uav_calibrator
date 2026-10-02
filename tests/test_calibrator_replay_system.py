from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/replay/replay_control_layout_pkg.sv','rtl/replay/replay_descriptor_queue.sv','rtl/replay/replay_legality_checker.sv','rtl/replay/frozen_replay_reader.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv','rtl/replay/replay_task_dispatcher.sv','rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/rx_cal_executor.sv','rtl/arithmetic/target_complex_operator.sv','rtl/replay/replay_processing_chain.sv','rtl/replay/task_doppler_phase.sv','rtl/replay/calibrator_replay_system.sv','tb/system/tb_calibrator_replay_system.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_replay_system','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/calibrator_replay_system.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS calibrator replay system' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
    # Actual RAM/RXCAL/target variant: quarter-turn task phase and deliberately
    # invalid external interface prove the production path owns its phasor.
    tb=(ROOT/'tb/system/tb_calibrator_replay_system.sv').read_text()
    tb=tb.replace(".phase_valid(1'b1)",".phase_valid(1'b0)")
    tb=tb.replace('make_task=t;',"t[DOPPLER_INITIAL_Q48_BIT+:64]=64'h400000000000;make_task=t;")
    tb=tb.replace('ck(out_qualified&&out_hv===expected,','expected=expected<<16;ck(out_qualified&&out_hv===expected,')
    alternate=Path(tmp)/'quarter.sv';alternate.write_text(tb)
    q=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_replay_system','-o',str(out),
        *[str(ROOT/s) for s in sources[:-1]],str(alternate)],capture_output=True,text=True,timeout=60)
    assert q.returncode==0,q.stdout+q.stderr
    q=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    assert q.returncode==0 and 'PASS calibrator replay system' in q.stdout,q.stdout+q.stderr
    print('PASS task phase through real RAM/RXCAL/target with external phase disabled')
    tb=(ROOT/'tb/system/tb_calibrator_replay_system.sv').read_text().replace(".phase_valid(1'b1)",".phase_valid(1'b0)")
    tb=tb.replace('make_task=t;',"t[DOPPLER_STEP_Q48_BIT+:64]=64'h100000000000;make_task=t;")
    tb=tb.replace('ck(out_qualified&&out_hv===expected,', '''case(((gsc-8)>>2)&3)
      1:expected=expected<<16;
      2:expected={48'd0,-expected[15:0]};
      3:expected={32'd0,-expected[15:0],16'd0};
      default:expected=expected;
     endcase
     ck(out_qualified&&out_hv===expected,''')
    alternate.write_text(tb)
    q=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_replay_system','-o',str(out),
        *[str(ROOT/s) for s in sources[:-1]],str(alternate)],capture_output=True,text=True,timeout=60)
    assert q.returncode==0,q.stdout+q.stderr
    q=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    assert q.returncode==0 and 'PASS calibrator replay system' in q.stdout,q.stdout+q.stderr
    print('PASS nonzero task Doppler frequency aligned to actual target input GSC through RAW/RXCAL/Target')
