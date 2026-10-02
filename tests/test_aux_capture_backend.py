from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
sources=sorted((ROOT/'rtl').rglob('*_pkg.sv'))
sources += [p for p in (ROOT/'rtl').rglob('*.sv') if not p.name.endswith('_pkg.sv')]
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_aux_capture_backend','-o',out,
        *map(str,sources),'tb/system/tb_aux_capture_backend.sv'],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0 and 'PASS AUX integrated backend' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
