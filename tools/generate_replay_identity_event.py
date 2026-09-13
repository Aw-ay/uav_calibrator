"""Generate replay identity EVENT ABI constants without changing CAPTURE_PDW."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def generate(root=ROOT):
 c=json.loads((ROOT/'contracts/replay_identity_event.json').read_text());covered=set()
 for n,o,z in c['fields']:
  span=set(range(o,o+z));assert not covered&span and o>=0 and o+z<=64;covered|=span
 assert covered==set(range(64))
 constants={'REPLAY_IDENTITY_BYTES':c['bytes'],'REPLAY_IDENTITY_TAG':c['tag']}
 constants.update({f'REPLAY_IDENTITY_{n.upper()}_OFFSET':o for n,o,z in c['fields']})
 products={
 'rtl/generated/replay_identity_event_pkg.sv':'// Generated from contracts/replay_identity_event.json\npackage replay_identity_event_pkg;\n'+''.join(f" localparam [31:0] {n}=32'd{v};\n" for n,v in constants.items())+'endpackage\n',
 'sw/common/include/replay_identity_event.h':'/* Generated from contracts/replay_identity_event.json */\n#ifndef REPLAY_IDENTITY_H\n#define REPLAY_IDENTITY_H\n'+''.join(f'#define {n} {v}u\n' for n,v in constants.items())+'#endif\n',
 'sw/matlab/replay_identity_event_constants.m':'% Generated from contracts/replay_identity_event.json\nfunction c=replay_identity_event_constants()\n'+''.join(f'c.{n}=uint32({v});\n' for n,v in constants.items())+'end\n',
 'docs/generated/replay_identity_event.md':'# Generated replay identity EVENT ABI\n\n|Field|Byte offset|Bytes|\n|---|---:|---:|\n'+''.join(f'|{n}|{o}|{z}|\n' for n,o,z in c['fields'])}
 for p,s in products.items():
  dest=Path(root)/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s,encoding='utf-8')
if __name__=='__main__':generate()
