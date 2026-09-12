from pathlib import Path
import random,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(712)
def q(x,s=16):
    b,r=divmod(x,1<<s);b+=r>(1<<(s-1)) or (r==(1<<(s-1)) and b%2)
    return max(-32768,min(32767,b)),int(b>32767 or b< -32768)
def pack(v,w):return sum((x&((1<<w)-1))<<(j*w) for j,x in enumerate(v))
lines=['module tb_calibration_dsp; reg clk=0;always #5 clk=~clk;reg rst=1,iv=0,cv=1,clear=0;reg signed [15:0] xi,xq,di,dq;reg signed [17:0] gi,gq;wire signed [15:0] ri,rq,ti,tq;wire rv,tv,rok,tok,rs,ts;',
'rx_cal_executor rx(clk,rst,iv,cv,xi,xq,di,dq,gi,gq,rv,rok,ri,rq,rs);tx_cal_executor tx(clk,rst,iv,cv,xi,xq,di,dq,gi,gq,tv,tok,ti,tq,ts);',
'reg [63:0] hv;reg [143:0] matrix;reg signed [17:0] pi,pq;wire [63:0] target;wire ov,ok,os;target_complex_operator op(clk,rst,iv,cv,hv,matrix,pi,pq,ov,ok,target,os);',
'reg [53:0] coeff;wire signed [15:0] fi,fq;wire fv,fok,fs;fractional_delay #(.TAPS(3)) fd(clk,rst,clear,iv,cv,xi,xq,coeff,fv,fok,fi,fq,fs);',
'reg signed [47:0] value;wire signed [15:0] rounded;wire sat;fixed_round_sat #(.IN_W(48),.OUT_W(16),.SHIFT(16)) quant(value,rounded,sat);',
'initial begin #12;rst=0;']
hist=[(0,0)]*2
target_pending=(0,0,0,0)
for n in range(400):
    vals=[rng.randrange(-32768,32768) for _ in range(8)];x,y,di,dq=vals[:4]
    g=[rng.randrange(-131072,131072) for _ in range(2)]
    mat=[rng.randrange(-131072,131072) for _ in range(8)];ph=[rng.randrange(-65536,65537) for _ in range(2)]
    co=[rng.randrange(-65536,65537) for _ in range(3)]
    if n<32:
        edge=[-32768,-32767,-3,-1,0,1,3,32767]
        vals=[edge[(n+j)%8] for j in range(8)];x,y,di,dq=vals[:4]
        g=[65536,0] if n%2 else [0,65536]
        mat=[65536,0,0,0,0,0,65536,0]
        ph=[65536,0] if n%2 else [0,-65536]
        co=[[65536,0,0],[0,65536,0],[32768,32768,0],[16384,32768,16384]][n%4]
    valid=int(n%13!=0);cv=int(n%17!=0);clr=int(n%31==0)
    if clr:hist=[(0,0)]*2
    rx=[q((x-di)*g[0]-(y-dq)*g[1]),q((x-di)*g[1]+(y-dq)*g[0])]
    tx=[q(x*g[0]-y*g[1]+(di<<16)),q(x*g[1]+y*g[0]+(dq<<16))]
    tar=[]
    for row in range(2):
        a,b,c,d=mat[row*4:row*4+4];h,j,v,k=vals[4:]
        ar=h*a-j*b+v*c-k*d;aq=h*b+j*a+v*d+k*c
        tar.extend([q(ar*ph[0]-aq*ph[1],32),q(ar*ph[1]+aq*ph[0],32)])
    target_expected=target_pending
    target_pending=(valid,pack([z[0] for z in tar],16) if cv else 0,int(cv and any(z[1] for z in tar)),int(valid and cv))
    target_expected_valid,target_expected_word,target_expected_sat,target_expected_ok=target_expected
    seq=[(x,y)]+hist;fd=[q(sum(seq[t][j]*co[t] for t in range(3))) for j in range(2)]
    if valid and not clr:hist=[(x,y)]+hist[:1]
    value=rng.choice([32767<<16,-32768<<16,rng.randrange(-(1<<47),1<<47),rng.randrange(-65536,65536)*65536+32768]);qr,qs=q(value)
    lines += [f'@(negedge clk);iv={valid};cv={cv};clear={clr};xi=16\'h{x&65535:x};xq=16\'h{y&65535:x};di=16\'h{di&65535:x};dq=16\'h{dq&65535:x};gi=18\'h{g[0]&262143:x};gq=18\'h{g[1]&262143:x};hv=64\'h{pack(vals[4:],16):x};matrix=144\'h{pack(mat,18):x};pi=18\'h{ph[0]&262143:x};pq=18\'h{ph[1]&262143:x};coeff=54\'h{pack(co,18):x};value=48\'h{value&((1<<48)-1):x};#1;',f'if(rounded!==16\'h{qr&65535:x} || sat!==1\'b{qs}) $fatal(1,"round {n}");','@(posedge clk);#1;',f'if(rv!=={valid} || tv!=={valid} || ov!=={target_expected_valid} || fv!=={int(valid and not clr)}) $fatal(1,"valid {n}");']
    for label,expected,validity,names in [('rx',rx,valid,['ri','rq','rs','rok']),('tx',tx,valid,['ti','tq','ts','tok']),('fd',fd,valid and not clr,['fi','fq','fs','fok'])]:
        if validity:
            aa,bb,ss,kk=names
            lines += [f'if({aa}!==16\'h{(expected[0][0] if cv else 0)&65535:x} || {bb}!==16\'h{(expected[1][0] if cv else 0)&65535:x} || {ss}!=={int(cv and any(z[1] for z in expected))} || {kk}!=={cv}) $fatal(1,"{label} {n}");']
    if target_expected_valid:lines += [f'if(target!==64\'h{target_expected_word:x} || os!=={target_expected_sat} || ok!=={target_expected_ok}) $fatal(1,"target {n}");']
lines += [f'@(negedge clk);iv=0;@(posedge clk);#1;if(ov!=={target_pending[0]} || target!==64\'h{target_pending[1]:x} || os!=={target_pending[2]} || ok!=={target_pending[3]}) $fatal(1,"target final pipeline drain");']
lines+=['@(negedge clk);rst=1;iv=1;@(posedge clk);#1;if(rv||tv||ov||fv||rok||tok||ok||fok||rs||ts||os||fs||ri||rq||ti||tq||target||fi||fq) $fatal(1,"reset clears all outputs");', '$display("PASS calibration DSP: 400 independent integer vectors, bubbles, reset, invalid tables, clear");$finish;end endmodule']
tb=ROOT/'tb/unit/tb_calibration_dsp.sv';tb.write_text('\n'.join(lines))
with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'dsp.vvp';src=list((ROOT/'rtl/arithmetic').glob('*.sv'))
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibration_dsp','-o',str(out),str(tb),*[str(x) for x in src]],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    (ROOT/'reports/calibration_dsp.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0,p.stdout+p.stderr
    print(p.stdout)


# Exhaustive small-width quantization proves zero shift and both signs of ties.
with tempfile.TemporaryDirectory() as tmp:
    exhaustive=['module tb_round_exhaustive;reg signed [7:0] x;wire signed [3:0] a,b,c;wire sa,sb,sc;',
    'fixed_round_sat #(.IN_W(8),.OUT_W(4),.SHIFT(0)) qa(x,a,sa);fixed_round_sat #(.IN_W(8),.OUT_W(4),.SHIFT(1)) qb(x,b,sb);fixed_round_sat #(.IN_W(8),.OUT_W(4),.SHIFT(3)) qc(x,c,sc);initial begin']
    for x in range(-128,128):
        exhaustive.append(f"x=8'h{x&255:x};#1;")
        for sh,name in [(0,'a'),(1,'b'),(3,'c')]:
            if sh:
                base,res=divmod(x,1<<sh)
                base+=int(res>(1<<(sh-1)) or (res==(1<<(sh-1)) and base%2))
            else:base=x
            val=max(-8,min(7,base));sat=int(base>7 or base< -8)
            exhaustive.append(f"if({name}!==4'h{val&15:x} || s{name}!==1'b{sat}) $fatal(1,\"shift{sh} input{x}\");")
    exhaustive.append('$display("PASS exhaustive quantizer: 768 cases SHIFT0/1/3");$finish;end endmodule')
    tb=Path(tmp)/'quant.sv';tb.write_text('\n'.join(exhaustive));out=Path(tmp)/'quant.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_round_exhaustive','-o',str(out),str(tb),str(ROOT/'rtl/arithmetic/fixed_round_sat.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    with (ROOT/'reports/calibration_dsp.log').open('a') as f:f.write(p.stdout+p.stderr)
    assert p.returncode==0,p.stdout+p.stderr
    print(p.stdout)

with tempfile.TemporaryDirectory() as tmp:
    out=Path(tmp)/'router.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_tx_channel_router','-o',str(out),str(ROOT/'tb/unit/tb_tx_channel_router.sv'),str(ROOT/'rtl/backend/tx_channel_router.sv')],capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True)
    with (ROOT/'reports/calibration_dsp.log').open('a') as f:f.write(p.stdout+p.stderr)
    assert p.returncode==0,p.stdout+p.stderr
    print(p.stdout)

# Diagnostic sweep of the explicitly non-qualified demonstration profile.
import math,cmath,json
worst_db=(0,0,0);worst_phase=(0,0,0)
for m in range(257):
    mu=m/256
    for f in range(501):
        hz=f*100000;w=2*math.pi*hz/125000000
        h=(1-mu)+mu*cmath.exp(-1j*w)
        db=20*math.log10(abs(h));phase=cmath.phase(h*cmath.exp(1j*w*mu))*180/math.pi
        if db<worst_db[0]:worst_db=(db,mu,hz)
        if abs(phase)>abs(worst_phase[0]):worst_phase=(phase,mu,hz)
result={'profile':'two-tap linear interpolation demonstration, NOT accepted wideband profile','fs_hz':125000000,'frequency_grid':'0..50MHz in100kHz; negative frequencies conjugate','fraction_grid':'0..1 inclusive in1/256','worst_magnitude_db':worst_db[0],'worst_magnitude_fraction':worst_db[1],'worst_magnitude_frequency_hz':worst_db[2],'worst_phase_error_deg':worst_phase[0],'worst_phase_fraction':worst_phase[1],'worst_phase_frequency_hz':worst_phase[2],'limitations':'coarse grid demonstration, not all65536 coefficient phases, no approved error allocation, no acceptance claim'}
(ROOT/'reports/fractional_delay_linear_profile.json').write_text(json.dumps(result,indent=2)+'\n')
print('DIAGNOSTIC fractional profile: %.3f dB magnitude, %.3f deg phase error; NOT bandwidth accepted'%(worst_db[0],abs(worst_phase[0])))
