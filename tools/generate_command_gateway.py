from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
c=json.loads((ROOT/'contracts/command_gateway.json').read_text())
sv=['// Generated from contracts/command_gateway.json','package command_gateway_pkg;']
h=['/* Generated from contracts/command_gateway.json */','#ifndef CAL_COMMAND_GATEWAY_H','#define CAL_COMMAND_GATEWAY_H']
for n,v in c['registers'].items():
    sv.append(f" localparam [31:0] GW_{n}=32'h{v:08x};")
    h.append(f'#define CAL_GW_{n} 0x{v:08x}u')
sv += [f" localparam [31:0] GW_ID_VALUE=32'h{c['id']:08x};",f" localparam integer GW_WORDS={c['words']};",'endpackage']
h += [f"#define CAL_GW_WORDS {c['words']}u",'#endif']
(ROOT/'rtl/generated/command_gateway_pkg.sv').write_text('\n'.join(sv)+'\n')
(ROOT/'sw/common/include/command_gateway.h').write_text('\n'.join(h)+'\n')
