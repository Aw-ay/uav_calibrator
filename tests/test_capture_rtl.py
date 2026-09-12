from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    sources=['rtl/capture/capture_bank_manager.sv','rtl/capture/capture_ram.sv','rtl/capture/capture_range_select.sv','rtl/capture/capture_bank_array.sv']
    for src in sources:
        assert (ROOT/src).exists(), 'Missing actual capture RTL: '+src
    for name in ['tb_capture','tb_capture_array','tb_capture_reset_hold','tb_capture_eop_gap']:
        simulate(name,sources)
def simulate(name,sources):
    out=ROOT/('reports/capture_'+name+'.vvp')
    subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',name,'-o',str(out),*[str(ROOT/s) for s in sources],str(ROOT/('tb/unit/'+name+'.sv'))],check=True)
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/('reports/capture_'+name+'.log')).write_text(p.stdout+p.stderr)
    assert p.returncode==0, p.stdout+p.stderr
    assert 'PASS capture' in p.stdout
    print(p.stdout)
if __name__=='__main__':run()
