"""Generate timing-only launch/capture registers around unchanged production RTL."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'tb/timing';out.mkdir(exist_ok=True)
for top in ('pulse_range_statistics','noise_snapshot','noise_window_energy','range_qualification'):
    text=(ROOT/f'rtl/capture/{top}.sv').read_text()
    header=re.search(r'module\s+'+top+r'\s*\((.*?)\);',text,re.S).group(1)
    ports=[];direction=None;width=''
    for item in header.split(','):
        item=item.strip()
        m=re.match(r'(input|output)\s+(?:wire|reg)\s*(\[[^]]+\])?\s*(\w+)$',item)
        if m: direction,width,name=m.groups();width=width or ''
        else:
            assert re.fullmatch(r'\w+',item),item
            name=item
        ports.append((direction,width,name))
    lines=['// Timing fixture only; adds launch/capture cycles, not a production wrapper.',
           f'module timing_{top}(', ' input wire timing_clk,']
    signals=[p for p in ports if p[2]!='clk']
    lines += [f' {d} wire {w} {n}'+(',' if k<len(signals)-1 else '') for k,(d,w,n) in enumerate(signals)]
    lines+=[');']
    for d,w,n in signals:
        if d=='input':
            lines += [f' (* DONT_TOUCH="true" *) reg {w} launch_{n};',f' always @(posedge timing_clk) launch_{n}<={n};']
        else:
            lines += [f' wire {w} dut_{n};',f' (* DONT_TOUCH="true" *) reg {w} capture_{n};',
                      f' always @(posedge timing_clk) capture_{n}<=dut_{n};',f' assign {n}=capture_{n};']
    lines += [f' {top} dut(']
    lines += [f' .{n}('+('timing_clk' if n=='clk' else ('launch_' if d=='input' else 'dut_')+n)+')'+(',' if k<len(ports)-1 else '') for k,(d,w,n) in enumerate(ports)]
    lines+=[' );','endmodule']
    (out/f'timing_{top}.sv').write_text('\n'.join(lines)+'\n')
    print(top,len(signals),'ports wrapped')
