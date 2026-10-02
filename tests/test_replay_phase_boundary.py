"""Earliest legal replay must have valid task phase on its very first sample."""
from pathlib import Path
import tempfile,subprocess
ROOT=Path(__file__).resolve().parents[1]
sources=['rtl/replay/replay_control_layout_pkg.sv','rtl/replay/replay_descriptor_queue.sv','rtl/replay/replay_legality_checker.sv','rtl/replay/frozen_replay_reader.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv','rtl/replay/replay_task_dispatcher.sv','rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/rx_cal_executor.sv','rtl/arithmetic/target_complex_operator.sv','rtl/replay/replay_processing_chain.sv','rtl/replay/task_doppler_phase.sv','rtl/replay/calibrator_replay_system.sv']
original=(ROOT/'tb/system/tb_calibrator_replay_system.sv').read_text()
a=original.index(' // Rejection evaluation');b=original.index('initial begin #50000;')
logs=[]
with tempfile.TemporaryDirectory() as tmp:
 for count,ref in [(1,0),(4,0),(7,3)]:
  for mode in range(4):
   tb=original[:a]+f" lifecycle_ready=1;enqueue(0,1,{count},gsc+{24+ref*4});\n while(!dsp_done)tick();ck(received=={count},\"earliest task exact samples\");\n $display(\"PASS earliest no-FD task phase warmup\");$finish;\nend\n"+original[b:]
   tb=tb.replace('if(received==0)',f'if(received=={ref})')
   tb=tb.replace('make_task=t;',f't[REFERENCE_SAMPLE_INDEX_BIT+:32]={ref};make_task=t;')
   if mode==1:
    tb=tb.replace('make_task=t;',"t[DOPPLER_INITIAL_Q48_BIT+:64]=64'h400000000000;make_task=t;")
    tb=tb.replace('ck(out_qualified&&out_hv===expected,','expected=expected<<16;ck(out_qualified&&out_hv===expected,')
   if mode>=2:
    tb=tb.replace('make_task=t;',"t[DOPPLER_STEP_Q48_BIT+:64]=64'h100000000000;"+f"t[DOPPLER_OUTPUT_OFFSET_TICKS_BIT+:64]={8 if mode==3 else 0};make_task=t;")
    tb=tb.replace('ck(out_qualified&&out_hv===expected,',f"case(((gsc-8+{8 if mode==3 else 0})>>2)&3) 1:expected=expected<<16;2:expected={{48'd0,-expected[15:0]}};3:expected={{32'd0,-expected[15:0],16'd0}};endcase\n ck(out_qualified&&out_hv===expected,")
   path=Path(tmp)/'tb.sv';path.write_text(tb);out=Path(tmp)/'sim'
   p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_calibrator_replay_system','-o',str(out),*sources,str(path)],cwd=ROOT,capture_output=True,text=True)
   assert p.returncode==0,p.stderr
   p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],cwd=ROOT,capture_output=True,text=True,timeout=60)
   assert p.returncode==0,(count,ref,mode,p.stdout,p.stderr)
   logs.append(f'PASS count={count} ref={ref} phase_mode={mode}: earliest first sample valid and target GSC exact')
 # The next dispatch may coincide with the previous DSP done pulse.
 tb=original[:a]+" lifecycle_ready=1;token_ready=1;enqueue(0,1,1,gsc+24);enqueue(1,2,1,gsc+52);\n while(received<2)tick();while(!idle)tick();\n $display(\"PASS adjacent task phase\");$finish;\nend\n"+original[b:]
 tb=tb.replace("expected=64'h1000+received;","expected=64'h1000;").replace('if(received==0)ck','ck')
 tb=tb.replace('integer received=0;',"reg saw_overlap=0;always @(posedge clk)if(dut.task_dispatching&&dsp_done)saw_overlap<=1;integer received=0;")
 tb=tb.replace('$display("PASS adjacent task phase");','if(!saw_overlap)$fatal(1,"dispatch/done overlap not covered");$display("PASS adjacent task phase");')
 path=Path(tmp)/'tb.sv';path.write_text(tb);out=Path(tmp)/'sim'
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_replay_system','-o',str(out),*sources,str(path)],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],cwd=ROOT,capture_output=True,text=True,timeout=60)
 assert p.returncode==0,p.stdout+p.stderr
 logs.append('PASS adjacent dispatch/done overlap: both first samples valid, exact GSC, no phase cancellation')
summary='\n'.join(logs)+'\nPASS13 earliest and adjacent scheduling task phase cases\n'
(ROOT/'reports/v06_replay_phase_boundary.log').write_text(summary)
print(summary)
