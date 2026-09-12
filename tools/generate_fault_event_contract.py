"""Generate fault EVENT ABI constants without changing CAPTURE_PDW."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def generate(root=ROOT):
 c=json.loads((ROOT/'contracts/fault_event_format.json').read_text());covered=set()
 for n,o,z in c['fields']:
  span=set(range(o,o+z));assert not covered&span and o>=0 and o+z<=64;covered|=span
 assert covered==set(range(64))
 constants={'FAULT_EVENT_BYTES':c['bytes'],'FAULT_EVENT_TAG':c['tag']}
 constants.update({f'FAULT_EVENT_{n.upper()}_OFFSET':o for n,o,z in c['fields']})
 constants.update({f'FAULT_EVENT_{n.upper()}':1<<b for n,b in c['flags'].items()})
 products={
 'rtl/generated/fault_event_pkg.sv':'// Generated from contracts/fault_event_format.json\npackage fault_event_pkg;\n'+''.join(f" localparam [31:0] {n}=32'd{v};\n" for n,v in constants.items())+'endpackage\n',
 'sw/common/include/fault_event.h':'/* Generated from contracts/fault_event_format.json */\n#ifndef FAULT_EVENT_H\n#define FAULT_EVENT_H\n'+''.join(f'#define {n} {v}u\n' for n,v in constants.items())+'#endif\n',
 'sw/matlab/fault_event_constants.m':'% Generated from contracts/fault_event_format.json\nfunction c=fault_event_constants()\n'+''.join(f'c.{n}=uint32({v});\n' for n,v in constants.items())+'end\n',
 'docs/generated/fault_event.md':'# Generated fault EVENT ABI\n\n|Field|Byte offset|Bytes|\n|---|---:|---:|\n'+''.join(f'|{n}|{o}|{z}|\n' for n,o,z in c['fields'])}
 for p,s in products.items():
  dest=Path(root)/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s,encoding='utf-8')
if __name__=='__main__':generate()
