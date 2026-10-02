from pathlib import Path
import subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'tests'),str(ROOT/'tools')]
from test_fine_engine import generate
from test_fine_stream import pulse
from fine_fixed import measure_fixed
# Use engine vectors for exact numerical expectations, but a separate service
# packing path and fixed identity/physical B-port model for scheduling verification.
for total in [16384]:
 with tempfile.TemporaryDirectory() as tmp:
  td=Path(tmp);generate(td)
  row=int((td/'jobs.hex').read_text().splitlines()[10],16) # use analytic generator below instead of ringing case11
  h=pulse(total,30,total-30);v=pulse(total,30,total-30,.43)
  g=measure_fixed(h,v,noise=(1000,1000),top_signal=(121000000,121000000),coarse=(30,total-30))
  (td/'service_samples.hex').write_text('\n'.join(f'{sum((x&65535)<<(16*j) for j,x in enumerate((*hi,*vi))):016x}' for hi,vi in zip(h,v)))
  records=[]
  for r in range(1,4):
   data=bytearray(128)
   flags=int(g['h']['snr_saturated'])|(int(g['v']['snr_saturated'])<<1)
   import struct
   struct.pack_into('<IIQQQIBBBBQ',data,0,0x40001,flags,11,9,17,42,r,0,int(r==1),0,123456)
   mask=0
   for p,k in enumerate(['h','v']):
    q=g[k];spec=q['spectral'];mask|=int(q['timing_valid'])<<p;mask|=int(spec['valid'])<<(p+2)
    struct.pack_into('<II',data,48+8*p,q['rise'].index_q16,q['fall'].index_q16)
    struct.pack_into('<I',data,64+4*p,121000000);struct.pack_into('<I',data,72+4*p,q['mean_body_power'])
    struct.pack_into('<i',data,80+4*p,spec.get('frequency_hz',0));struct.pack_into('<q',data,88+8*p,spec.get('chirp_hz_per_s',0))
    struct.pack_into('<I',data,108+4*p,q['snr_q16']);struct.pack_into('<H',data,116+2*p,q['edge_quality']);data[120+p]=spec['quality']
   mask|=int(g['hv']['valid'])<<4;data[39]=mask;data[122]=g['hv']['quality'];struct.pack_into('<i',data,104,g['hv'].get('phase_q31',0))
   records.append(data[::-1].hex())
  (td/'service_expected.hex').write_text('\n'.join(records));sim=str(td/'sim')
  sources=['rtl/generated/calibrator_contract_pkg.sv','rtl/generated/fine_edge_program_pkg.sv','rtl/control/cdc_mailbox.sv','rtl/capture/b_port_reader_128.sv']
  sources += ['rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv']
  sources += [str(p.relative_to(ROOT)) for p in (ROOT/'rtl/fine').glob('*.sv')]
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_fine_sustained',f'-Ptb_fine_sustained.TOTAL={total}','-o',sim,*sources,'tb/system/tb_fine_sustained.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0 and not any(x in p.stderr for x in ['expects','implicit definition','dangling input']),p.stdout+p.stderr
  # Wall-clock budget accommodates concurrent synthesis; simulated deadline and watchdog stay strict.
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}'],capture_output=True,text=True,timeout=900)
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
  (ROOT/f'reports/v06_fine_sustained.log').write_text(p.stdout+p.stderr);print(p.stdout)
