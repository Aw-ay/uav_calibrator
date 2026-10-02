from pathlib import Path
import zipfile,xml.etree.ElementTree as E
r=Path(__file__).resolve().parents[1]
with zipfile.ZipFile(r/'build/platform_counter_stage26_r4/platform_counter.xsa') as z:
 root=E.fromstring(z.read('platform_counter.hwh'))
 modules={m.get('INSTANCE'):m for m in root.findall('.//MODULE')}
 def p(n):return {x.get('NAME'):x.get('VALUE') for x in modules[n].findall('./PARAMETERS/PARAMETER')}
 dma=p('axi_dma_s2mm');gpio=p('counter_control');ps=p('ps_0')
 for k,v in {'C_INCLUDE_SG':'1','C_S_AXIS_S2MM_TDATA_WIDTH':'128','C_M_AXI_S2MM_ADDR_WIDTH':'40','C_BASEADDR':'0xA0040000'}.items():assert dma[k]==v,(k,dma[k])
 assert gpio['C_BASEADDR']=='0xA0050000'
 assert ps['PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ']=='96.968727'
 assert ps['PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ']=='199.998001'
 assert modules['counter_cdc'].get('MODTYPE')=='axis_clock_converter'
 assert modules['counter_source'].get('MODTYPE')=='platform_counter_bd'
 assert 'zynq_ultra_ps_e' in [m.get('MODTYPE') for m in modules.values()]
 print('PASS counter XSA: actual clocks, DMA SG/128-bit/40-bit, GPIO addresses and hardware handoff')
