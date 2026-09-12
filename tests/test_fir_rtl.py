"""Independent direct convolution versus actual compiled SSR RTL, no DSP libraries."""
import hashlib,json,random,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
COEFF=json.loads((ROOT/'contracts/fir_coefficients.json').read_text())['stages']
def quant(v,shift,bits):
    q,r=divmod(v,1<<shift)
    q+=r>(1<<(shift-1)) or (r==(1<<(shift-1)) and q%2)
    sat=not -(1<<(bits-1))<=q<(1<<(bits-1))
    return max(-(1<<(bits-1)),min((1<<(bits-1))-1,q)),int(sat)
def stage(samples,key,interp,shift,bits):
    x=[v for s in samples for v in ([s,0] if interp else [s])]
    c=COEFF[key]['integers']; y=[]; flags=[]
    for n in range(0,len(x),1 if interp else 2):
        v=sum(c[k]*x[n-k] for k in range(min(n+1,len(c))))
        q,f=quant(v,shift,bits); y.append(q);flags.append(f)
    return y,flags
def packed(vals,bits=16):
    return sum((v&((1<<bits)-1))<<(bits*k) for k,v in enumerate(vals))
def run():
    assert hashlib.sha256((ROOT/'contracts/fir_coefficients.json').read_bytes()).hexdigest() == '8523fcf1018f481f2ea01615446bc633dd570d2a60e78a198afa341b22405597', 'Frozen coefficient source changed; review before regenerating expected data'
    for p in ['rtl/frontend/fir_rx_lane.sv','rtl/backend/fir_tx_lane.sv']:
        assert (ROOT/p).exists(), 'Missing actual FIR implementation: '+p
    rng=random.Random(50911)
    records={}
    for direction,lanes,latency in [('rx',4,15),('tx',1,14)]:
        inputs=[]; expected=[]; cycles=[]
        for epoch in range(3):
            n=420
            a=[0]*(n*lanes); b=a.copy()
            if epoch==0:
                a[0]=32767;b[3*lanes]=-32768
                for j in range(90*lanes,200*lanes): a[j]=32767;b[j]=-32768
            else:
                a=[rng.randrange(-32768,32768) for _ in a]
                b=[rng.randrange(-32768,32768) for _ in b]
                a[-90*lanes:]=[0]*(90*lanes);b[-90*lanes:]=[0]*(90*lanes)
            keys=['RX_HB19_D2','RX_FIR75_D2'] if direction=='rx' else ['TX_FIR75_L2','TX_HB19_L2']
            aa,fa=stage(a,keys[0],direction=='tx',11 if direction=='rx' else 10,24)
            bb,fb=stage(b,keys[0],direction=='tx',11 if direction=='rx' else 10,24)
            ya,ga=stage(aa,keys[1],direction=='tx',23 if direction=='rx' else 22,16)
            yb,gb=stage(bb,keys[1],direction=='tx',23 if direction=='rx' else 22,16)
            ol=1 if direction=='rx' else 4; mid=2
            # Reset discards in-flight products and clears all filter history.
            cycles += [(1,0,0,0)]*2 + [(0,1,packed([32767]*lanes),packed([-32768]*lanes))]*3 + [(1,0,0,0)]*2
            for k in range(n):
                if rng.random()<.18: cycles.append((0,0,0,0))
                cycles.append((0,1,packed(a[k*lanes:(k+1)*lanes]),packed(b[k*lanes:(k+1)*lanes])))
                expected.append((packed(ya[k*ol:(k+1)*ol]),packed(yb[k*ol:(k+1)*ol]),int(any(fa[k*mid:(k+1)*mid]+fb[k*mid:(k+1)*mid])) | (int(any(ga[k*ol:(k+1)*ol]+gb[k*ol:(k+1)*ol]))<<1)))
            cycles += [(0,0,0,0)]*(latency+2)
        vector=ROOT/f'tb/vectors/fir_{direction}.txt';vector.parent.mkdir(parents=True,exist_ok=True)
        vector.write_text(''.join(f'{r} {v} {a:x} {b:x}\n' for r,v,a,b in cycles))
        tb=ROOT/f'tb/unit/tb_fir_{direction}.sv';tb.parent.mkdir(parents=True,exist_ok=True)
        ib=lanes*16;ob=(1 if direction=='rx' else 4)*16
        tb.write_text(f'''module tb_fir_{direction};
reg clk=0; always #4 clk=~clk;
reg rst=1,in_valid=0; reg [{ib-1}:0] in_i=0,in_q=0;
wire out_valid; wire [{ob-1}:0] out_i,out_q; wire [1:0] out_sat;
fir_{direction}_lane dut(.*);
integer fd,rc,cycle=0; reg [{latency-1}:0] valid_ref=0;
initial begin
 fd=$fopen("tb/vectors/fir_{direction}.txt","r");
 while (!$feof(fd)) begin
 @(negedge clk); rc=$fscanf(fd,"%d %d %h %h\\n",rst,in_valid,in_i,in_q);
 @(posedge clk);
 if(rst) valid_ref=0; else valid_ref={{valid_ref[{latency-2}:0],in_valid}};
 #1; if(out_valid!==valid_ref[{latency-1}]) $fatal(1,"latency cycle %0d",cycle);
 if(out_valid) $display("DATA %h %h %h",out_i,out_q,out_sat);
 cycle=cycle+1;
 end
 $finish; end
endmodule
''')
        files=[str(p.relative_to(ROOT)) for folder in ['frontend','backend'] for p in (ROOT/'rtl'/folder).glob('fir*.sv')]
        out=ROOT/f'tb/vectors/fir_{direction}.vvp'
        subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',f'tb_fir_{direction}','-o',str(out),*files,str(tb)],cwd=ROOT,check=True,capture_output=True,text=True)
        result=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],cwd=ROOT,check=True,capture_output=True,text=True)
        actual=[tuple(int(v,16) for v in line.split()[1:]) for line in result.stdout.splitlines() if line.startswith('DATA ')]
        assert len(actual)==len(expected),(direction,len(actual),len(expected))
        for k,(actual_row,expected_row) in enumerate(zip(actual,expected)):
            assert actual_row==expected_row,(direction,k,actual_row,expected_row)
        records[direction]={'complex_beats_compared':len(actual),'latency_registers':latency,'II':1,'output_saturation_beats':sum(bool(row[2]&2) for row in actual)}
    # Directly exercise signed ties-to-even and both saturation boundaries.
    quant_checks=0
    for shift,bits in [(11,24),(23,16),(10,24),(22,16)]:
        values=[]
        for base in [-3,-2,-1,0,1,2,3,-(1<<(bits-1))-1,-(1<<(bits-1)),(1<<(bits-1))-1,1<<(bits-1)]:
            for residue in [0,(1<<(shift-1))-1,1<<(shift-1),(1<<(shift-1))+1,(1<<shift)-1]:
                values.append(base*(1<<shift)+residue)
        body=[]
        for value in values:
            q,sat=quant(value,shift,bits)
            body.append(f"value=48'h{value&((1<<48)-1):012x}; #1; if(result!=={bits}'h{q&((1<<bits)-1):x} || sat!==1'b{sat}) $fatal(1,\"quant mismatch\");")
        tb=ROOT/'tb/unit/tb_fir_quantize.sv'
        tb.write_text(f'''module tb_fir_quantize;
reg signed [47:0] value; wire signed [{bits-1}:0] result; wire sat;
fir_quantize #(.SHIFT({shift}),.BITS({bits})) dut(.*);
initial begin
'''+ '\n'.join(body)+'\n$finish; end\nendmodule\n')
        out=ROOT/'tb/vectors/fir_quantize.vvp'
        subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fir_quantize','-o',str(out),'rtl/frontend/fir_quantize.sv',str(tb)],cwd=ROOT,check=True,capture_output=True,text=True)
        subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],cwd=ROOT,check=True,capture_output=True,text=True)
        quant_checks+=len(values)
    records['directed_round_saturate_cases']=quant_checks
    records['coefficient_json_sha256']=hashlib.sha256((ROOT/'contracts/fir_coefficients.json').read_bytes()).hexdigest()
    (ROOT/'reports').mkdir(exist_ok=True)
    (ROOT/'reports/fir_rtl_simulation.json').write_text(json.dumps(records,indent=2)+'\n')
    print(json.dumps(records,indent=2))
if __name__=='__main__':run()
