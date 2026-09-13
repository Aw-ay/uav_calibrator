"""Generate TX lifecycle EVENT ABI constants without changing CAPTURE_PDW."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def generate(root=ROOT):
 c=json.loads((ROOT/'contracts/tx_lifecycle_event.json').read_text());covered=set()
 for n,o,z in c['fields']:
  span=set(range(o,o+z));assert not covered&span and o>=0 and o+z<=64;covered|=span
 assert covered==set(range(64))
 constants={'TX_LIFECYCLE_BYTES':c['bytes'],'TX_LIFECYCLE_TAG':c['tag']}
 constants.update({f'TX_LIFECYCLE_{n.upper()}_OFFSET':o for n,o,z in c['fields']})
 constants.update({f'TX_LIFECYCLE_{n.upper()}':1<<b for n,b in c['flags'].items()})
 for group in ('sources','reasons'):
  constants.update({f'TX_LIFECYCLE_{group[:-1].upper()}_{n}':v for n,v in c[group].items()})
 products={
 'rtl/generated/tx_lifecycle_event_pkg.sv':'// Generated from contracts/tx_lifecycle_event.json\npackage tx_lifecycle_event_pkg;\n'+''.join(f" localparam [31:0] {n}=32'd{v};\n" for n,v in constants.items())+'endpackage\n',
 'sw/common/include/tx_lifecycle_event.h':'/* Generated from contracts/tx_lifecycle_event.json */\n#ifndef TX_LIFECYCLE_H\n#define TX_LIFECYCLE_H\n'+''.join(f'#define {n} {v}u\n' for n,v in constants.items())+'#endif\n',
 'sw/matlab/tx_lifecycle_event_constants.m':'% Generated from contracts/tx_lifecycle_event.json\nfunction c=tx_lifecycle_event_constants()\n'+''.join(f'c.{n}=uint32({v});\n' for n,v in constants.items())+'end\n',
 'docs/generated/tx_lifecycle_event.md':'# Generated TX lifecycle EVENT ABI\n\n|Field|Byte offset|Bytes|\n|---|---:|---:|\n'+''.join(f'|{n}|{o}|{z}|\n' for n,o,z in c['fields'])}
 for p,s in products.items():
  dest=Path(root)/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s,encoding='utf-8')
if __name__=='__main__':generate()
