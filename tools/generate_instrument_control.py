from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'contracts/instrument_control.json').read_text())
sv=['// Generated from contracts/instrument_control.json','package instrument_control_pkg;',f" localparam integer CONFIG_WORDS={d['config_words']};"]
h=['/* Generated from contracts/instrument_control.json */','#ifndef CAL_INSTRUMENT_CONTROL_H','#define CAL_INSTRUMENT_CONTROL_H',f"#define CAL_CONFIG_WORDS {d['config_words']}u"]
sv.append(f" localparam integer PDW_QUEUE_DEPTH={d['pdw_queue_depth']};");h.append(f"#define CAL_PDW_QUEUE_DEPTH {d['pdw_queue_depth']}u")
for n,v in (d['source_event_constants'] | d['rf_fault_constants']).items():
    sv.append(f" localparam [31:0] {n}=32'd{v};");h.append(f'#define CAL_{n} {v}u')
for f in d['config_fields']:
    for suffix,value in [('BIT',f['bit']),('WIDTH',f['width'])]:
        n='CFG_'+f['name'].upper()+'_'+suffix
        sv.append(f' localparam integer {n}={value};');h.append(f'#define CAL_{n} {value}u')
for n,o in d['commands'].items():
    sv.append(f" localparam [15:0] CMD_{n}=16'd{o['opcode']};")
    sv.append(f" localparam [15:0] CMD_{n}_WORDS=16'd{o['words']};")
    h.append(f"#define CAL_CMD_{n} {o['opcode']}u")
    h.append(f"#define CAL_CMD_{n}_WORDS {o['words']}u")
    if 'result_words' in o:
        sv.append(f" localparam [15:0] CMD_{n}_RESULT_WORDS=16'd{o['result_words']};")
        h.append(f"#define CAL_CMD_{n}_RESULT_WORDS {o['result_words']}u")
mask=sum(((1<<f['width'])-1)<<f['bit'] for f in d['config_fields'])
sv.append(f" localparam [8191:0] CONFIG_MASK=8192'h{mask:02048x};")
sv.append('endpackage');h.append('#endif')
(ROOT/'rtl/generated/instrument_control_pkg.sv').write_text('\n'.join(sv)+'\n')
(ROOT/'sw/common/include/instrument_control.h').write_text('\n'.join(h)+'\n')
