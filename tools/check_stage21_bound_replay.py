from pathlib import Path
import subprocess,sys,tempfile,shutil
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reports/instrument_stage21'
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources
s=(ROOT/'tb/system/tb_calibrator_instrument_core.sv').read_text()
changes=[('tx_sink_binding_valid=0,tx_sink_fence_ready=0','tx_sink_binding_valid=1,tx_sink_fence_ready=0'),('retirement[32+:32]!=3','retirement[32+:32]!=7'),('PASS REPLAY_LIFECYCLE_CORE','PASS REPLAY_BOUND_CORE')]
for a,b in changes:
 assert a in s,a
 s=s.replace(a,b)
anchor=' calibrator_instrument_core #'
assert anchor in s
s=s.replace(anchor,""" // Test-only RF-domain receiver: bank must already be released before ACK.
 integer sink_wait=0;
 always @(posedge rf_clk)begin
  if(!rst_n)begin tx_sink_ack_valid<=0;tx_sink_fence_ready<=0;sink_wait<=0;end
  else begin
   tx_sink_ack_valid<=tx_sink_fence_valid&&tx_sink_fence_ready;
   tx_sink_ack_token<=tx_sink_fence_token;
   if(tx_sink_fence_valid&&!tx_sink_fence_ready)begin
    if(dut.d_replay_leased!=0)$fatal(1,\"sink wait retained RAW lease\");
    sink_wait<=sink_wait+1;if(sink_wait==12)tx_sink_fence_ready<=1;
   end
  end
 end
"""+anchor)
tb=OUT/'tb_core_bound_replay.sv';tb.write_text(s)
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);shutil.copyfile(ROOT/'build/capture_system_vectors/headers.hex',d/'headers.hex');sim=d/'sim'
 commands=[['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_calibrator_instrument_core','-o',str(sim),*sources,str(tb)],['C:/iverilog/bin/vvp.exe',str(sim),'+ROOT='+d.as_posix()]]
 for cmd in commands:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=240)
  if(cmd[0].endswith('vvp.exe')):(OUT/'bound_replay.log').write_text(p.stdout+p.stderr)
  assert p.returncode==0,p.stdout+p.stderr
 assert 'PASS REPLAY_BOUND_CORE' in p.stdout
 print('PASS instrument bound replay: RAW bank released before delayed sink ACK, exact identity and confirmed retirement')
