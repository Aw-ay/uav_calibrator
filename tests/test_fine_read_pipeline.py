"""Real B128 reader + cache + stats, bank wrap and finite request/drain bounds."""
from pathlib import Path
import subprocess,tempfile
from test_fine_accumulator import generate
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 td=Path(tmp);n,jobs=generate(td);logs=[]
 for latency in [1,2,3]:
  sim=str(td/f'sim{latency}')
  p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fine_read_pipeline',
    f'-Ptb_fine_read_pipeline.LATENCY={latency}','-o',sim,
    'rtl/capture/b_port_reader_128.sv','rtl/fine/fine_sample_cache.sv',
    'rtl/fine/fine_segment_accumulator.sv','tb/unit/tb_fine_read_pipeline.sv'],cwd=ROOT,capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={td.as_posix()}',f'+COUNT={n}',f'+JOBS={jobs}'],capture_output=True,text=True,timeout=60)
  logs.append(p.stdout+p.stderr)
  assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
 (ROOT/'reports/v06_fine_read_pipeline.log').write_text('\n'.join(logs))
 print('\n'.join(logs))
