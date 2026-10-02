from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def run():
    logs=[]
    for latency,depth in ((lat,depth) for lat in (1,2,3) for depth in (8,16)):
        out=ROOT/f'reports/v06_b_reader_l{latency}_d{depth}.vvp'
        cmd=['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_b_port_reader_128',
             f'-Ptb_b_port_reader_128.LATENCY={latency}',f'-Ptb_b_port_reader_128.FIFO_WORDS={depth}','-o',str(out),
             str(ROOT/'rtl/capture/b_port_reader_128.sv'),str(ROOT/'tb/unit/tb_b_port_reader_128.sv')]
        p=subprocess.run(cmd,capture_output=True,text=True)
        assert p.returncode==0,p.stdout+p.stderr
        p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
        logs.append(p.stdout+p.stderr)
        (ROOT/'reports/v06_b_reader.log').write_text('\n'.join(logs))
        assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print('\n'.join(logs))
if __name__=='__main__':run()
