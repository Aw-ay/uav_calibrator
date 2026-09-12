from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    files=['dds_burst_control','dds_nco_wrapper','awg_reader','awg_load_cdc_wrapper','generated_tx_sources']
    assert (ROOT/'rtl/source/generated_tx_sources.sv').exists(),'NOT_IMPLEMENTED generated_tx_sources'
    out=ROOT/'reports/tb_generated_tx_sources.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_generated_tx_sources','-o',str(out),*[str(ROOT/f'rtl/source/{m}.sv') for m in files],str(ROOT/'tb/unit/tb_generated_tx_sources.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/'reports/tb_generated_tx_sources.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
if __name__=='__main__':run()
