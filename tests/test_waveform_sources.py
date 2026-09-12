from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    files=['dds_burst_control','dds_nco_wrapper','tx_source_mux','awg_reader']
    for name in files:
        assert (ROOT/f'rtl/source/{name}.sv').exists(), f'NOT_IMPLEMENTED {name}'
    for bench in ['tb_waveform_sources','tb_awg_reader']:
        out=ROOT/f'reports/{bench}.vvp'
        p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',bench,'-o',str(out),*[str(ROOT/f'rtl/source/{n}.sv') for n in files],str(ROOT/f'tb/unit/{bench}.sv')],capture_output=True,text=True)
        assert p.returncode==0,p.stdout+p.stderr
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
        (ROOT/f'reports/{bench}.log').write_text(p.stdout+p.stderr)
        assert p.returncode==0,p.stdout+p.stderr
        assert 'PASS' in p.stdout
        print(p.stdout)
if __name__=='__main__':run()
