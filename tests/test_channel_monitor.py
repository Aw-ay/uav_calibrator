from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    modules=['frontend/channel_epoch_aligner','monitor/tx_reference_analyzer']
    for m in modules:
        assert (ROOT/f'rtl/{m}.sv').exists(),f'NOT_IMPLEMENTED {m}'
    for tb in ['tb_channel_epoch_aligner','tb_tx_reference_analyzer']:
        out=ROOT/f'reports/{tb}.vvp'
        p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',tb,'-o',str(out),*[str(ROOT/f'rtl/{m}.sv') for m in modules],str(ROOT/f'tb/unit/{tb}.sv')],capture_output=True,text=True)
        assert p.returncode==0,p.stdout+p.stderr
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
        (ROOT/f'reports/{tb}.log').write_text(p.stdout+p.stderr)
        assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
        print(p.stdout)
if __name__=='__main__':run()
