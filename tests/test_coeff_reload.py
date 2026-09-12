from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    rtl=ROOT/'rtl/control/coeff_reload_bridge.sv'
    assert rtl.exists(),'NOT_IMPLEMENTED coeff_reload_bridge'
    out=ROOT/'reports/tb_coeff_reload.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_coeff_reload','-o',str(out),str(rtl),str(ROOT/'tb/unit/tb_coeff_reload.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/'reports/tb_coeff_reload.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
if __name__=='__main__':run()
