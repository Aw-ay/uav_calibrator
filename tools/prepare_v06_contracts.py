"""Import new v0.6 contracts without rolling back post-GitHub local extensions."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
PACKAGE=ROOT/'docs/releases/v0.6_DRFM_FINE_DMA'
def main():
    sums=json.loads((PACKAGE/'SHA256SUMS.json').read_text(encoding='utf-8'))['files']
    for name,expected in sums.items():
        assert hashlib.sha256((PACKAGE/name).read_bytes()).hexdigest()==expected,name
    for name in ('b_port_reader','fine_measurement','fine_pdw_format','fine_result_transport'):
        value=json.loads((PACKAGE/f'contracts/{name}.json').read_text(encoding='utf-8'))
        if name=='fine_result_transport':
            value['schema_version']=2
            value['commands']['CMD_FINE_PDW_PEEK']['opcode']=25
            value['commands']['CMD_FINE_PDW_POP']['opcode']=26
            value['compatibility_resolution']={
                'package_revision':1,'package_opcodes':[22,23],
                'local_reserved_opcodes':{'AUX_CAPTURE':22,'AUX_META_PEEK':23,'AUX_META_POP':24},
                'reason':'Local stage27 AUX predates this migration but postdates package GitHub base.',
                'implementation_status':'RESERVED_NOT_YET_CONNECTED'}
        if name=='b_port_reader':
            value['status']='IMPLEMENTED_ACTIVE_DMA_PATH'
            value['ram_read_latency']=1
            value['latency_evidence']='reports/v06_bmg_latency.log; actual capture_ram_probe XSim 2025.2'
            value['latency_convention']='request sampled at edge n; registered downstream consumes corresponding RAM data at edge n+1'
        (ROOT/f'contracts/{name}.json').write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    local=json.loads((ROOT/'contracts/instrument_control.json').read_text())
    used={v['opcode'] for v in local['commands'].values()}
    assert not used & {25,26},'Fine allocation conflicts with actual control ABI'
    print(f'PASS package SHA256: {len(sums)} files; Fine opcodes 25/26 reserved, AUX22..24 preserved')
if __name__=='__main__':main()
