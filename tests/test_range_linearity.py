from pathlib import Path
import subprocess,tempfile,random
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'sim.vvp'
    sources=['rtl/capture/range_linearity.sv','tb/unit/tb_range_linearity.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_range_linearity','-o',str(out),*[str(ROOT/s) for s in sources]],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    (ROOT/'reports/range_linearity.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS range linearity' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
    rng=random.Random(120926)
    prefix=(ROOT/'tb/unit/tb_range_linearity.sv').read_text().split(' initial begin')[0]
    lines=[' initial begin']
    for case in range(160):
        es=[rng.randrange(1,1<<46) for _ in range(6)]
        scales=[rng.randrange(1,1<<32) for _ in range(6)]
        cv=rng.randrange(64);ov=rng.randrange(64);tol=rng.randrange(65536)
        ck=rng.randrange(2);cp=rng.randrange(2)
        pk=pp=lk=lp=0
        norm=[e*s for e,s in zip(es,scales)]
        pairs=[(0,1),(1,2),(0,2),(3,4),(4,5),(3,5)]
        for j,(a,b) in enumerate(pairs):
            known=bool(cv>>a&1 and cv>>b&1 and ov>>a&1 and ov>>b&1)
            passed=known and abs(norm[a]-norm[b])*65536<=max(norm[a],norm[b])*tol
            pk|=int(known)<<j;pp|=int(passed)<<j
        for c in range(6):
            relevant=[j for j,pair in enumerate(pairs) if c in pair and pk>>j&1]
            known=bool(ck and relevant)
            passed=known and cp and all(pp>>j&1 for j in relevant)
            lk|=int(known)<<c;lp|=int(passed)<<c
        pack=lambda values,width:sum(v<<(i*width) for i,v in enumerate(values))
        lines += [f" energy=276'h{pack(es,46):x};power_scale_q16=192'h{pack(scales,32):x};",
                  f" calibration_valid=6'd{cv};overlap_valid=6'd{ov};tolerance_q16=16'd{tol};common_known={ck};common_pass={cp};#1;",
                  f' check(pair_known=={pk}&&pair_pass=={pp}&&linearity_known=={lk}&&linearity_pass=={lp},"Python big-integer oracle case {case}");']
    lines += ['$display("PASS 160 Python big-integer linearity vectors");$finish;end','endmodule']
    tb=Path(tmp)/'oracle.sv';tb.write_text(prefix+'\n'.join(lines))
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_range_linearity','-o',str(out),str(ROOT/'rtl/capture/range_linearity.sv'),str(tb)],capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=60)
    assert p.returncode==0 and 'PASS 160' in p.stdout,p.stdout+p.stderr
    with (ROOT/'reports/range_linearity.log').open('a') as f:f.write(p.stdout+p.stderr)
    print(p.stdout)
