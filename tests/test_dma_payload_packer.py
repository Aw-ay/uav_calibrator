from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    out=ROOT/'reports/v06_dma_packer.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_dma_payload_packer','-o',str(out),str(ROOT/'rtl/capture/dma_payload_packer.sv'),str(ROOT/'tb/unit/tb_dma_payload_packer.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/'reports/v06_dma_packer.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
if __name__=='__main__':run()
