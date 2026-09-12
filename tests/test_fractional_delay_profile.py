from pathlib import Path
import subprocess,tempfile,random,json
ROOT=Path(__file__).resolve().parents[1]
# Generator must reproduce coefficients and sweep all256 phases before RTL testing.
p=subprocess.run(['python',str(ROOT/'tools/generate_fractional_delay.py')],cwd=ROOT,capture_output=True,text=True)
assert p.returncode==0,p.stdout+p.stderr
print(p.stdout)
profile=json.loads((ROOT/'contracts/fractional_delay_profile.json').read_text())
assert profile['metrics']['max_amplitude_error_db']<=0.01
assert profile['metrics']['max_phase_error_deg']<=0.1
rom_text=(ROOT/'rtl/generated/fractional_delay_coeff_rom.sv').read_text()
assert profile['coefficient_sha256'] in rom_text and '$readmem' not in rom_text
import re,hashlib
embedded=re.findall(r"8'd\d+: coefficients=1134'h([0-9a-f]+);",rom_text)
assert len(embedded)==256
assert '\n'.join(embedded)+'\n' == (ROOT/'rtl/coefficients/fractional_delay_63x256_q16.mem').read_text()
assert hashlib.sha256(('\n'.join(embedded)+'\n').encode()).hexdigest()==profile['coefficient_sha256']
coeff=[]
for row in (ROOT/'rtl/coefficients/fractional_delay_63x256_q16.mem').read_text().splitlines():
    packed=int(row,16);c=[]
    for k in range(63):
        v=(packed>>(18*k))&262143;c.append(v-262144 if v&131072 else v)
    assert sum(c)==65536
    coeff.append(c)
rng=random.Random(20260912)
def quant(v):
    a,r=divmod(v,65536);a+=int(r>32768 or (r==32768 and a%2))
    return max(-32768,min(32767,a)),int(a>32767 or a< -32768)
with tempfile.TemporaryDirectory() as tmp:
    tmp=Path(tmp);vectors=[]
    for phase in range(256):
        history=[(0,0)]*62
        for n in range(142):
            x=rng.randrange(-32768,32768);y=rng.randrange(-32768,32768)
            if n<4:x=[32767,-32768,0,1][n];y=-x if x!=-32768 else 32767
            if n>=80:x=y=0
            seq=[(x,y)]+history
            a,sa=quant(sum(seq[k][0]*coeff[phase][k] for k in range(63)))
            b,sb=quant(sum(seq[k][1]*coeff[phase][k] for k in range(63)))
            word=(x&65535)|((y&65535)<<16)|((a&65535)<<32)|((b&65535)<<48)|((sa|sb)<<64)
            vectors.append(f'{word:017x}')
            history=seq[:62]
    vf=tmp/'vectors.mem';vf.write_text('\n'.join(vectors)+'\n');(ROOT/'build/fd_profile_vectors.mem').write_text(vf.read_text());out=tmp/'fd.vvp'
    sources=['rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/fractional_delay.sv','rtl/arithmetic/fractional_delay_pipelined.sv','rtl/generated/fractional_delay_coeff_rom.sv','rtl/arithmetic/fractional_delay_profile.sv','tb/unit/tb_fractional_delay_profile.sv']
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_fractional_delay_profile','-o',str(out),*[str(ROOT/s) for s in sources]],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out),f'+VECTORS={vf.as_posix()}'],cwd=tmp,capture_output=True,text=True,timeout=120)
    (ROOT/'reports/fractional_delay_profile.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0,p.stdout+p.stderr
    print(p.stdout)

