from pathlib import Path
import subprocess,sys,tempfile
root=Path.cwd();sys.path.insert(0,str(root/'tests'))
from test_calibrator_dataplane_system import sources,vectors
v=vectors();s=Path('tb/system/tb_instrument_waveform_commands.sv').read_text()
for a,b in [('tx_sink_binding_valid=1','tx_sink_binding_valid=0'),('if(value!=7)$fatal(1,"TX lifecycle flags")','if(value!=3)$fatal(1,"TX lifecycle flags")'),('if(tx_rows==0&&retired-drained<12)','if(1\'b0&&tx_rows==0&&retired-drained<12)'),('protocol_errors!=1||fence_wait!=13','protocol_errors!=0||fence_wait!=0')]:
 assert a in s,a
 s=s.replace(a,b)
out=Path('reports/instrument_stage17');tb=out/'tb_waveform_unbound.sv';tb.write_text(s)
with tempfile.TemporaryDirectory() as tmp:
 sim=str(Path(tmp)/'sim')
 cmd=['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_instrument_waveform_commands','-o',sim,*sources,str(tb)]
 p=subprocess.run(cmd,capture_output=True,text=True,timeout=120);assert p.returncode==0,p.stderr
 assert not any(t in p.stderr for t in ['implicit definition','dangling input','expects']),p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={v.as_posix()}'],capture_output=True,text=True,timeout=240)
 (out/'unbound_sink.log').write_text(p.stdout+p.stderr)
 assert p.returncode==0 and 'PASS TX_LIFECYCLE_CORE' in p.stdout,p.stdout+p.stderr
 print('PASS actual instrument DDS/AWG without sink binding: seven digital-only retirement records, no fence/ACK, no false sink confirmation')
