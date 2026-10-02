"""Require fresh v0.6 DMA evidence; preserve unimplemented Fine/replay boundaries."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def timing(path):
 text=path.read_text()
 match=re.search(r'WNS\(ns\).*?\n\s*-+[^\n]*\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)',text,re.S)
 assert match,path
 values=match.groups()
 result=dict(wns=float(values[0]),tns=float(values[1]),setup_failing=int(values[2]),
  whs=float(values[4]),hold_failing=int(values[6]),wpws=float(values[8]),pulse_failing=int(values[10]))
 assert result['wns']>=0 and result['whs']>=0 and result['wpws']>=0 and not any(result[k] for k in ('setup_failing','hold_failing','pulse_failing')),result
 return result
def resources(path):
 text=path.read_text();out={}
 for name,key in [('CLB LUTs','lut'),('CLB Registers','ff'),('Block RAM Tile','bram'),('DSPs','dsp')]:
  match=re.search(r'\| '+re.escape(name)+r'\*?\s*\|\s*([\d.]+)',text);assert match,name
  out[key]=float(match[1])
 return out
def cdc(path):
 text=path.read_text();assert 'CDC Report' in text
 result={'Critical':0,'Warning':0,'Info':0}
 for severity,count in re.findall(r'^CDC-\d+\s+(Critical|Warning|Info)\s+(\d+)\s',text,re.M):result[severity]+=int(count)
 assert result['Critical']==0,result
 return result
def constraints(path):
 result={name:int(count) for name,count in re.findall(r'checking (\w+) \((\d+)\)',path.read_text())}
 for key in ('no_clock','unconstrained_internal_endpoints','loops'):assert result[key]==0,(key,result[key])
 return result
def main():
 ext=json.loads((ROOT/'reports/v06_external_baseline.json').read_text())
 assert all(sha(ROOT/p)==h for p,h in ext.items()),'Pre-existing external files changed'
 snapshot=json.loads((ROOT/'reports/v06_dma_inputs.json').read_text())
 synth_names={p:h for p,h in snapshot['files'].items() if p.startswith('rtl/')}
 assert all(sha(ROOT/p)==h for p,h in synth_names.items()),'RTL changed after synthesis input snapshot'
 assert all(sha(ROOT/p)==h for p,h in snapshot['memory_files'].items()),'Coefficient memory changed during synthesis'
 regression=json.loads((ROOT/'reports/v06_dma_regression.json').read_text())
 assert regression['status']=='PASS' and len(regression['results'])==103
 checks={
  'reports/v06_bmg_latency.log':'PASS actual capture_ram_probe A_READ_LATENCY=1 B_READ_LATENCY=1',
  'reports/v06_bmg_stream.log':'PASS B128 frame 131216 bytes, 8211 cycles, payload steady streak 8192',
  'reports/v06_b_reader.log':'FIFO=16',
  'reports/v06_dma_packer.log':'PASS DMA packer',
  'reports/instrument_v06_dma.log':'INSTRUMENT_V06_DMA_SYNTH_COMPLETE',
  'reports/v06_project_verify.log':'DIGITAL_PROJECT_REOPEN_OK',
 }
 for path,marker in checks.items():assert marker in (ROOT/path).read_text(errors='replace'),path
 modules={}
 for name in ('b_port_reader_128','dma_payload_packer','record_formatter_128'):
  folder=ROOT/'reports/v06_modules'/name
  modules[name]=dict(timing=timing(folder/'timing_synth.rpt'),resources=resources(folder/'utilization.rpt'))
 core=ROOT/'reports/instrument_v06_dma'
 result={'utc':datetime.now(timezone.utc).isoformat(),'status':'PASS_DIGITAL_DMA_BATCH_ONLY',
  'regression_entries':103,'regression_utc':regression['utc'],'modules':modules,
  'digital_core':{'timing':timing(core/'timing_synth.rpt'),'resources':resources(core/'utilization.rpt'),
   'cdc_unwaived':cdc(core/'cdc.rpt'),'constraints':constraints(core/'check_timing.rpt')},
  'bmg_stream_simulation':{'record_bytes':131216,'cycles':8211,'clock_hz':200000000,'record_Bps':131216*200000000/8211,'continuous_payload_beats':8192},
  'preserved_external_files':ext,'synth_RTL_sha256':synth_names,'coefficient_memory_sha256':snapshot['memory_files'],
  'not_completed':['online statistics','Fine engine and three-bank analysis','three bank references/B fabric','Fine commands/IRQ','active FD63 removal','full v0.6 integration','board DDR and physical latency acceptance'],
  'boundary':'Synthesis/OOC estimates and simulation; no board connected; no measured DDR throughput'}
 (ROOT/'reports/v06_dma_delivery.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items() if k not in ('synth_RTL_sha256','preserved_external_files')},indent=2))
if __name__=='__main__':main()
