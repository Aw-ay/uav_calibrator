from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    source=ROOT/'rtl/source/awg_load_cdc_wrapper.sv'
    assert source.exists(),'NOT_IMPLEMENTED awg_load_cdc_wrapper'
    for ctrl_half,rf_half in [(5,4),(3,7),(7,3)]:
        check(source,ctrl_half,rf_half)
def check(source,ctrl_half,rf_half):
    out=ROOT/f'reports/tb_awg_load_cdc_{ctrl_half}_{rf_half}.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_awg_load_cdc',f'-Ptb_awg_load_cdc.CTRL_HALF={ctrl_half}',f'-Ptb_awg_load_cdc.RF_HALF={rf_half}','-o',str(out),str(ROOT/'rtl/source/awg_reader.sv'),str(source),str(ROOT/'tb/unit/tb_awg_load_cdc.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/f'reports/tb_awg_load_cdc_{ctrl_half}_{rf_half}.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
if __name__=='__main__':run()
