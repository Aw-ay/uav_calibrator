"""Generate AUX sidecar field constants from one contract."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def generate(root=ROOT):
 c=json.loads((ROOT/'contracts/aux_metadata.json').read_text());covered=set()
 for n,o,z in c['fields']:
  span=set(range(o,o+z));assert z in (1,2,4,8) and not covered&span and o>=0 and o+z<=c['bytes'];covered|=span
 assert covered==set(range(c['bytes']))
 constants={'AUX_META_MAGIC':c['magic'],'AUX_META_VERSION':c['version'],'AUX_META_BYTES':c['bytes']}
 constants.update({f'AUX_META_{n.upper()}_OFFSET':o for n,o,z in c['fields']})
 products={
 'rtl/generated/aux_metadata_pkg.sv':'// Generated; edit contracts/aux_metadata.json\npackage aux_metadata_pkg;\n'+''.join(f" localparam [31:0] {n}=32'd{v};\n" for n,v in constants.items())+'endpackage\n',
 'sw/common/include/aux_metadata.h':'/* Generated */\n#ifndef AUX_METADATA_H\n#define AUX_METADATA_H\n'+''.join(f'#define {n} {v}u\n' for n,v in constants.items())+'#endif\n',
 'sw/matlab/aux_metadata_constants.m':'% Generated\nfunction c=aux_metadata_constants()\n'+''.join(f'c.{n}=uint32({v});\n' for n,v in constants.items())+'end\n',
 'docs/generated/aux_metadata.md':'# AUX metadata ABI\n\n|Field|Offset|Bytes|\n|---|---:|---:|\n'+''.join(f'|{n}|{o}|{z}|\n' for n,o,z in c['fields'])}
 for p,s in products.items():
  dest=Path(root)/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s,encoding='utf-8')
if __name__=='__main__':generate()
