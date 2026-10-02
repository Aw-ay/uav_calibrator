"""Paired actual-core replay trace: Fine disabled/zero DMA vs Fine busy/random DMA.
Only the TB suppresses Fine dispatch in the baseline. Production RTL is unchanged.
"""
from pathlib import Path
import subprocess, tempfile, sys, re
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources,vectors
headers=vectors()/'headers.hex'
original=(ROOT/'tb/system/tb_calibrator_instrument_core.sv').read_text()
cut='  binding_valid=0;#1;if(native_dac_data!=0)$fatal(1,"binding loss zero code");'
assert cut in original
prefix=original[:original.index(cut)]
old='  m_axis_tready=1;wait(frames==1&&completions==1);repeat(20)@(negedge rf_clk);'
assert old in prefix
traces=[]
with tempfile.TemporaryDirectory() as tmp:
 td=Path(tmp)
 for mode in [0,1]:
  out=td/str(mode);out.mkdir();(out/'headers.hex').write_bytes(headers.read_bytes())
  monitor="""
 reg isolation_dma_enable=0;reg [31:0] isolation_rng=32'h76543210;
 reg isolation_fine_busy=0;
 always @(negedge mem_clk)if(isolation_dma_enable)begin
  isolation_rng={isolation_rng[30:0],isolation_rng[31]^isolation_rng[21]^isolation_rng[1]^isolation_rng[0]};
  m_axis_tready=isolation_rng[0]&&isolation_rng[3];
 end
 always @(posedge rf_clk)if(rst_n)begin
  if(dut.d_r_actual_start)$display("ISOLATION_START %0d",dut.d_r_actual_start_gsc);
  if(dut.d_r_raw_valid)begin
   $display("ISOLATION_RAW %0d %016x",gsc,dut.d_r_raw_data);
   if(dut.dataplane.capture.backend.fine_path.service.engine_busy)isolation_fine_busy=1;
  end
 end
"""
  if mode==0:monitor+=' initial force dut.dataplane.capture.backend.fine_path.service.send=0;\n'
  code=prefix.replace(' import command_gateway_pkg::*;',monitor+' import command_gateway_pkg::*;')
  code=code.replace(old,f'  isolation_dma_enable={mode};repeat(200)@(negedge rf_clk);')
  code+='  if('+str(mode)+'&&!isolation_fine_busy)$fatal(1,"Fine busy overlap missing");\n'
  code+='  $display("PASS actual core Fine/DMA replay isolation variant");$finish;\n end\nendmodule\n'
  tb=out/'tb.sv';tb.write_text(code);sim=out/'sim'
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_instrument_core','-o',str(sim),*sources,str(tb)],cwd=ROOT,capture_output=True,text=True,timeout=120)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(sim),f'+ROOT={out.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=600)
  (ROOT/f'reports/v06_fine_replay_isolation_{mode}.log').write_text(p.stdout+p.stderr)
  assert p.returncode==0 and 'PASS actual core Fine/DMA replay isolation variant' in p.stdout,p.stdout+p.stderr
  trace=re.findall(r'^ISOLATION_(?:START|RAW) .*$',p.stdout,re.M)
  assert len(trace)>2 and sum(x.startswith('ISOLATION_START') for x in trace)==1,trace
  traces.append(trace)
 assert traces[0]==traces[1],(traces[0],traces[1])
 summary=f'PASS actual instrument replay: identical actual_start_gsc and {len(traces[0])-1} RAW IQ/GSC beats with zero DMA/no Fine versus random DMA stalls/Fine busy'
 (ROOT/'reports/v06_fine_replay_isolation.log').write_text(summary+'\n')
 print(summary)
