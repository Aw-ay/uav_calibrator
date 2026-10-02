"""Independent integer oracle for the active RXCAL->Target path, no FD sources."""
from pathlib import Path
import random, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(6011)
def quant(x,shift):
    base,remainder=divmod(x,1<<shift)
    rounded=base+int(remainder>(1<<(shift-1)) or (remainder==(1<<(shift-1)) and base&1))
    return max(-32768,min(32767,rounded)),int(not -32768<=rounded<=32767)
def pack(values,bits):
    return sum((v&((1<<bits)-1))<<(bits*i) for i,v in enumerate(values))
def mul(a,b):return (a[0]*b[0]-a[1]*b[1],a[0]*b[1]+a[1]*b[0])
lines=[]
for job in range(20):
    dc=[rng.randint(-32768,32767) for _ in range(4)]
    gains=[rng.randint(-131072,131071) for _ in range(4)]
    matrix=[rng.randint(-131072,131071) for _ in range(8)]
    phase=[rng.randint(-65536,65536) for _ in range(2)]
    if job==0:
        dc=[0]*4;gains=[32768,0,32768,0];matrix=[65536,0,0,0,0,0,65536,0];phase=[65536,0]
    lines.append(f'{pack(dc,16):016x} {pack(gains,18):018x} {pack(matrix,18):036x} {phase[0]&0x3ffff:05x} {phase[1]&0x3ffff:05x}')
    for n in range(32):
        raw=[rng.choice([-32768,32767,0,1,-1]) if n<8 else rng.randint(-32768,32767) for _ in range(4)]
        cal=[];saturated=0
        for lane in range(2):
            z=mul([raw[lane*2+i]-dc[lane*2+i] for i in range(2)],gains[lane*2:lane*2+2])
            for v in z:
                q,c=quant(v,16);cal.append(q);saturated|=c
        result=[]
        for row in range(2):
            h=mul(cal[:2],matrix[row*4:row*4+2]);v=mul(cal[2:],matrix[row*4+2:row*4+4])
            z=mul([h[i]+v[i] for i in range(2)],phase)
            for value in z:
                q,c=quant(value,32);result.append(q);saturated|=c
        lines.append(f'{pack(raw,16):016x} {pack(result,16):016x} {saturated}')
with tempfile.TemporaryDirectory() as tmp:
    vf=Path(tmp)/'vectors.txt';vf.write_text('\n'.join(lines)+'\n');out=Path(tmp)/'sim'
    sources=['rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/rx_cal_executor.sv','rtl/arithmetic/target_complex_operator.sv','rtl/replay/replay_processing_chain.sv','tb/system/tb_replay_no_fd_vectors.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_replay_no_fd_vectors','-o',str(out),*sources],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out),f'+VECTORS={vf.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=60)
    (ROOT/'reports/v06_replay_no_fd_vectors.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0,p.stdout+p.stderr
    print(p.stdout)
