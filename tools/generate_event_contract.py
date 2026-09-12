"""Generate the capture-event ABI constants for SV, C and MATLAB from JSON."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def generate(root=ROOT):
    c=json.loads((ROOT/'contracts/event_format.json').read_text(encoding='utf-8'))
    covered=set();names=set()
    for n,o,z in c['fields']:
        assert n not in names and z in (4,8) and o>=0 and o+z<=c['bytes']
        span=set(range(o,o+z));assert not covered&span
        covered|=span;names.add(n)
    assert covered==set(range(64))
    constants={'EVENT_BYTES':c['bytes'],'EVENT_CAPTURE_TAG':c['tag']}
    constants.update({f'EVENT_{n.upper()}_OFFSET':o for n,o,z in c['fields']})
    constants.update({f'EVENT_{n.upper()}_VALID':1<<b for n,b in c['valid_bits'].items()})
    products={
      'rtl/generated/capture_event_pkg.sv':'// Generated from contracts/event_format.json\npackage capture_event_pkg;\n'+''.join(f' localparam logic [31:0] {n}=32\'d{v};\n' for n,v in constants.items())+'endpackage\n',
      'sw/common/include/capture_event.h':'/* Generated from contracts/event_format.json */\n#ifndef CAPTURE_EVENT_H\n#define CAPTURE_EVENT_H\n'+''.join(f'#define {n} {v}u\n' for n,v in constants.items())+'#endif\n',
      'sw/matlab/capture_event_constants.m':'% Generated from contracts/event_format.json\nfunction c=capture_event_constants()\n'+''.join(f'c.{n}=uint32({v});\n' for n,v in constants.items())+'end\n',
      'docs/generated/capture_event.md':'# Generated capture event ABI\n\n|Field|Byte offset|Bytes|\n|---|---:|---:|\n'+''.join(f'|{n}|{o}|{z}|\n' for n,o,z in c['fields'])}
    for path,data in products.items():
        p=Path(root)/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(data,encoding='utf-8')
if __name__=='__main__':generate()
