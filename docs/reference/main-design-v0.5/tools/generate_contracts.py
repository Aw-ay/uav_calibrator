"""Generate numeric C/SV constants and byte offsets from active JSON contracts.
No drivers, RTL implementation, device pinout, or Vivado IP is generated.
"""
from pathlib import Path
import argparse,json,re
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/'contracts'/f'{name}.json').read_text(encoding='utf-8'))
def clean(name):return re.sub(r'[^A-Z0-9_]','_',name.upper())
def build_outputs():
    s=read('system_contract');b=read('bank_contract');p=read('record_policy');f=read('frame_format');r=read('register_map');d=read('replay_contract')
    values={'ABI_VERSION':f['abi_version'],'ADC_COUNT':8,'PRIMARY_ADC_MASK':0x77,'AUX_ADC_MASK':0x88,'ALL_ADC_MASK':0xff,
      'CORE_HZ':s['rates']['core_complex_hz'],'FIR_CLOCK_HZ':s['clock_targets']['fir_compute_hz'],
      'DMA_CLOCK_HZ':p['dma']['clock_hz'],'RFDC_COMPLEX_HZ':s['rates']['rfdc_complex_hz'],
      'RFDC_COMPLEX_SPC':s['rates']['canonical_input_complex_spc'],'PL_DECIMATION':s['rates']['pl_decimation'],
      'PL_INTERPOLATION':s['tx_profile']['pl_interpolation'],'GSC_TICK_NS':2,'GSC_CORE_STRIDE':s['rates']['gsc_increment_per_rf_clock'],
      'GROUPS':b['groups'],'BANKS_PER_GROUP':b['banks_per_group'],'BANK_DEPTH':b['samples_per_bank'],
      'BANK_ADDR_BITS':b['address_bits'],'BANK_COUNT_BITS':b['sample_count_bits'],'HV_SAMPLE_BYTES':8,
      'RAW_CAPTURE_BYTES':b['raw_bytes_total'],'DMA_DATA_BITS':p['dma']['axis_bits'],'DMA_SLOT_BYTES':p['dma']['slot_bytes'],
      'DMA_SLOTS':p['dma']['slots'],'DMA_POOL_BYTES':p['dma']['pool_bytes'],'HEADER_BYTES':f['header_bytes'],
      'MAX_RECORD_BYTES':f['max_record_bytes_with_trailer'],'PL_TAIL_ZERO_SAMPLES':read('fir_plan')['latency']['pl_tail_zero_input_samples_min']}
    for x in r['registers']:values['REG_'+clean(x['name'])+'_OFFSET']=int(x['offset_hex'],16)
    values['REG_BANK_SNAPSHOT_BASE']=int(r['bank_snapshot_table']['base_hex'],16)
    values['REG_BANK_SNAPSHOT_STRIDE']=r['bank_snapshot_table']['stride_bytes']
    for x in f['header']:
        values['FRAME_'+clean(x['name'])+'_OFFSET']=x['offset_bytes'];values['FRAME_'+clean(x['name'])+'_BYTES']=x['size_bytes']
    for key in ['capture_descriptor','replay_task','return_token']:
        values[clean(key)+'_BYTES']=d[key]['size_bytes']
        for x in d[key]['fields']:values[clean(key)+'_'+clean(x['name'])+'_OFFSET']=x['offset_bytes']
    ch=['/* Generated from active JSON contracts. Numeric design targets, NOT validated hardware. */',
        '#ifndef CALIB_CONTRACT_H','#define CALIB_CONTRACT_H','#include <stdint.h>']
    sv=['// Generated constants only; not an implemented datapath.', 'package calib_contract_pkg;']
    for n,v in values.items():
        ch.append(f'#define CALIB_{n} UINT32_C({v})')
        sv.append(f'  localparam int unsigned {n} = {v};')
    ch+=['/* Wire data is little-endian; use offsets, not unaligned native struct casts. */',
         '#endif /* CALIB_CONTRACT_H */','']
    sv+=['endpackage : calib_contract_pkg','']
    return {'generated/calib_contract.h':'\n'.join(ch),'generated/calib_contract_pkg.sv':'\n'.join(sv),
            'generated/constants.json':json.dumps(values,indent=2,sort_keys=True)+'\n'}
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');a=ap.parse_args()
    failures=[]
    for name,text in build_outputs().items():
        p=ROOT/name
        if a.check:
            if not p.exists() or p.read_text(encoding='utf-8')!=text:failures.append(name)
        else:p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
    if failures:raise SystemExit('Generated files stale/missing: '+', '.join(failures))
    print('Generated contract constants: '+('MATCH' if a.check else 'WRITTEN'))
if __name__=='__main__':main()
