"""Eight independent physical lanes versus direct Python integer convolution."""
import json, random, subprocess
from pathlib import Path
from test_fir_rtl import stage, packed
ROOT=Path(__file__).resolve().parents[1]

def run():
    rng=random.Random(8911)
    cycles=[]
    for n in range(310):
        rst=n<2 or n in (205,206)
        acq=not (n<3 or 165<=n<171)
        av=0xffff
        if n in (82,83,117,190): av &= ~(1 << (6 if n!=117 else 11))
        ai=[[rng.randrange(-6000,6000) for _ in range(4)] for c in range(8)]
        aq=[[rng.randrange(-6000,6000) for _ in range(4)] for c in range(8)]
        ti=[rng.randrange(-4000,4000) for c in range(8)]
        tq=[rng.randrange(-4000,4000) for c in range(8)]
        if 30<=n<76:
            ai=[[32767]*4 for c in range(8)];aq=[[-32768]*4 for c in range(8)]
            ti=[32767]*8;tq=[-32768]*8
        tv=0xff if n%7 else 0x55
        mask=0xa5 if 100<=n<110 else 0xff
        permit=not 130<=n<137
        fault=145<=n<150
        native=packed([v for c in range(8) for seq in (ai[c],aq[c]) for v in seq])
        cycles.append((int(rst),int(acq),native,av,packed(ti),packed(tq),tv,mask,int(permit),int(fault),ai,aq,ti,tq))
    expected=[[0,0,0,0,0,0,0] for _ in cycles]
    # Model contiguous acquisition epochs, substituting four zeros on either
    # missing I/Q native stream. No sample-time compression is permitted.
    for direction in ('rx','tx'):
        pos=0
        while pos<len(cycles):
            active=lambda row: not row[0] and (row[1] if direction=='rx' else True)
            if not active(cycles[pos]): pos+=1;continue
            end=pos
            while end<len(cycles) and active(cycles[end]): end+=1
            keys=('RX_HB19_D2','RX_FIR75_D2') if direction=='rx' else ('TX_FIR75_L2','TX_HB19_L2')
            delay=14 if direction=='rx' else 13
            for c in range(8):
                vals=[[],[]]
                for row in cycles[pos:end]:
                    valid=((row[3]>>(2*c))&3)==3 if direction=='rx' else bool(row[6]&(1<<c))
                    for iq in range(2):
                        val=row[10+iq][c] if direction=='rx' else [row[12+iq][c]]
                        vals[iq].extend(val if valid else [0]*len(val))
                ys=[]; fs=[]; gs=[]
                for val in vals:
                    mid,f=stage(val,keys[0],direction=='tx',11 if direction=='rx' else 10,24)
                    y,g=stage(mid,keys[1],direction=='tx',23 if direction=='rx' else 22,16)
                    ys.append(y);fs.append(f);gs.append(g)
                for n in range(pos+delay,end):
                    k=n-pos-delay
                    ol=1 if direction=='rx' else 4
                    sat=any(fs[0][k*2:k*2+2]+fs[1][k*2:k*2+2]+gs[0][k*ol:(k+1)*ol]+gs[1][k*ol:(k+1)*ol])
                    if sat: expected[n][5 if direction=='rx' else 6]|=1<<c
                    if direction=='rx':
                        expected[n][0]|=(ys[0][k]&65535)<<(16*c)
                        expected[n][1]|=(ys[1][k]&65535)<<(16*c)
                        expected[n][2]|=1<<c
                    else:
                        row=cycles[n]
                        if row[8] and not row[9] and row[7]&(1<<c):
                            words=[v for j in range(4) for v in (ys[0][4*k+j],ys[1][4*k+j])]
                            expected[n][4]|=packed(words)<<(128*c)
            pos=end
    # Independent causal support: the cascaded impulse response spans
    # (19-1)+2*(75-1)=166 high-rate intervals. A four-sample missing
    # beat can reach decimated output index floor((3+166)/4)=42.
    # The output arrives 14 clock intervals later: last affected m+56.
    last_affected=(3+(19-1)+2*(75-1))//4+14
    assert last_affected==56
    for n,row in enumerate(cycles):
        for c in range(8):
            causal_window=cycles[max(0,n-last_affected):n+1]
            uncertain=any(r[0] or not r[1] or ((r[3]>>(2*c))&3)!=3 for r in causal_window)
            if not uncertain and expected[n][2]&(1<<c) and not expected[n][5]&(1<<c): expected[n][3]|=1<<c
    assert not expected[139][3]&(1<<3),'last missing beat at83 must cover output139'
    assert expected[140][3]&(1<<3),'unaffected output140 should recover quality'
    assert any(row[5] for row in expected),'RX stimulus must exercise saturation'
    assert any(row[6] for row in expected),'TX stimulus must exercise saturation'
    vectors=ROOT/'tb/vectors/eight_channel.txt'; vectors.parent.mkdir(parents=True,exist_ok=True)
    vectors.write_text(''.join(' '.join(f'{v:x}' for v in row[:10])+'\n' for row in cycles))
    files=[str(p.relative_to(ROOT)) for folder in ('frontend','backend') for p in (ROOT/'rtl'/folder).glob('*.sv')]
    out=ROOT/'tb/vectors/eight_channel.vvp'
    result=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_eight_channel','-o',str(out),'rtl/calibrator_top.sv',*files,'tb/system/tb_eight_channel.sv'],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    result=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],cwd=ROOT,check=True,capture_output=True,text=True)
    actual=[list(int(v,16) for v in line.split()[1:]) for line in result.stdout.splitlines() if line.startswith('DATA ')]
    assert len(actual)==len(expected),(len(actual),len(expected))
    for n,(got,want) in enumerate(zip(actual,expected)):
        # RX data has no meaning until valid; all DAC output words always do.
        if not want[2]: got[0:2]=[0,0]
        assert got==want,(n,[hex(v) for v in got],[hex(v) for v in want])
    print(json.dumps({'status':'PASS','cycles':len(cycles),'physical_rx_lanes':8,'physical_tx_lanes':8,'comparison':'independent direct integer convolution','missing_adc_cycles':[82,83,117,190],'acquisition_restart':171,'reset_restart':207}))

if __name__=='__main__': run()
