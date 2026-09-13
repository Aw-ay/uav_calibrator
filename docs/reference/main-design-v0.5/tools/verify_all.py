"""Recompute v0.5 evidence. Does not run Vivado, RTL, RFDC or a physical board."""
from pathlib import Path
import csv,hashlib,importlib.util,json,math,os,platform,re,shutil,subprocess,sys,tempfile,time
import numpy as np
import scipy
from scipy import signal
os.environ['PYTHONUTF8']='1'
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
OUT=ROOT/'reports';OUT.mkdir(exist_ok=True)
def dump(n,x): (OUT/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def read(n):return json.loads((ROOT/'contracts'/f'{n}.json').read_text(encoding='utf-8'))
def coeff(file):
    with (ROOT/file).open(encoding='utf-8') as f:return np.array([int(r['integer']) for r in csv.DictReader(f)],np.int64)
def run(cmd,log):
    p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
    (OUT/log).write_text(p.stdout+p.stderr,encoding='utf-8')
    if p.returncode:raise RuntimeError(f'{cmd} failed; see {log}\n{p.stdout}{p.stderr}')
    return p.stdout+p.stderr

def static_checks():
    names=[]
    for p in (ROOT/'contracts').glob('*.json'):json.loads(p.read_text(encoding='utf-8'));names.append(p.name)
    b=read('bank_contract');s=read('system_contract');f=read('fir_plan');p=read('record_policy')
    assert b['groups']*b['banks_per_group']*b['samples_per_bank']*b['sample_bits']//8 == s['capture']['raw_bytes_initial']==2097152
    assert s['rates']['rfdc_complex_hz']//s['rates']['pl_decimation']==s['rates']['core_complex_hz']==125000000
    assert s['rates']['clk_rf_hz']*s['rates']['canonical_input_complex_spc']==500000000
    assert p['dma']['clock_hz']*p['dma']['axis_bits']//8==3200000000
    assert read('frame_format')['max_record_bytes_with_trailer']==128+8*16384+16
    assert read('frame_format')['abi_version']==5
    assert not p['dma']['cyclic_mode']
    # Exact integer COE and CSV identities, paired RX/TX prototypes and bit points.
    for direction,stages in [('RX',f['rx_stages']),('TX',f['tx_stages'])]:
        for k,st in enumerate(stages,1):
            text=(ROOT/st['coefficient_file']).read_text(encoding='utf-8');raw=text.split('coefdata=')[1].strip().rstrip(';')
            q=np.array([int(t.strip()) for t in raw.split(',') if t.strip()],np.int64)
            np.testing.assert_array_equal(q,coeff(f'filters/{direction}_STAGE{k}.csv'))
            assert len(q)==st['taps'] and np.array_equal(q,q[::-1])
            meta=json.loads((ROOT/f'filters/{direction}_STAGE{k}_metadata.json').read_text(encoding='utf-8'))
            assert meta['coefficient_fraction_bits']==(17 if direction=='RX' else 16)
            assert st['clock_hz']==125000000
    np.testing.assert_array_equal(coeff('filters/RX_STAGE1.csv'),coeff('filters/TX_STAGE2.csv'))
    np.testing.assert_array_equal(coeff('filters/RX_STAGE2.csv'),coeff('filters/TX_STAGE1.csv'))
    # All actual clocks in semantic implementation targets remain125/200/100.
    assert all('clk_fir' not in m['clocks'] for m in read('module_catalog')['modules'])
    modnames={m['name'] for m in read('module_catalog')['modules']}
    assert 'sample_rate_gearbox' not in modnames
    assert {'rx_decim4_wrapper','tx_interp4_wrapper','fixed_round_sat'}<=modnames
    for file in ['system_contract','amd_ip_targets','fir_plan','module_catalog','bd_connections']:
        d=read(file)
        def check(x,path=''):
            if isinstance(x,dict):
                for k,v in x.items():
                    if isinstance(v,(int,float)) and (('clock' in k.lower() or k=='clk_rf_hz') and 'sample' not in k.lower()):
                        assert v!=250000000,(file,path+k)
                    check(v,path+k+'/')
            elif isinstance(x,list):
                for i,v in enumerate(x):check(v,path+str(i)+'/')
        check(d)
    # Address aperture and register reserved-range overlap checks.
    used=[]
    for seg in read('address_map')['segments']:
        lo=int(seg['base_hex'],16);hi=lo+seg['size_bytes'];assert all(hi<=a or lo>=z for a,z in used);used.append((lo,hi))
    reg=read('register_map')
    for rg in reg['reserved_groups']:
        lo,hi=(int(v,16) for v in rg.split('-'))
        assert not any(lo<=int(r['offset_hex'],16)<=hi for r in reg['registers']),rg
    # Relative markdown downloads must exist, including source archives after provenance merge.
    broken=[];checked=0
    for md in [ROOT/'README.md',ROOT/'修改说明.md',*sorted((ROOT/'specs').glob('*.md'))]:
        for dest in re.findall(r'\]\(([^)]+)\)',md.read_text(encoding='utf-8')):
            if dest.startswith(('http:','https:','#','mailto:')):continue
            dest=dest.split('#')[0]
            if dest and not (md.parent/dest).exists():broken.append((str(md.relative_to(ROOT)),dest))
            checked+=1
    assert not broken,broken
    return dict(contract_files=len(names),json_valid=True,clock_and_rate_ledger=True,coefficient_files_exact=True,
                no_active_fir_250_clock=True,relative_markdown_links_checked=checked,broken_links=[],address_and_reserved_ranges_valid=True)

def numeric_reports():
    q1=coeff('filters/RX_STAGE1.csv');q2=coeff('filters/RX_STAGE2.csv')
    h1=q1/2**17;h2=q2/2**17;expanded=np.zeros((len(h2)-1)*2+1);expanded[::2]=h2
    he=np.convolve(h1,expanded)
    freq,H=signal.freqz(he,worN=262145,include_nyquist=True,fs=500e6)
    _,edge=signal.freqz(he,worN=np.array([50e6,62.5e6]),fs=500e6)
    pb=np.r_[np.abs(H[freq<=50e6]),abs(edge[0])];sb=np.r_[np.abs(H[freq>=62.5e6]),abs(edge[1])]
    f={'status':'COEFFICIENT_DOMAIN_ONLY','ripple_db':float(20*np.log10(pb.max()/pb.min())),
       'stop_db':float(-20*np.log10(sb.max())),'dc_gain_db':float(20*np.log10(he.sum())),
       'group_delay_ns':float((len(he)-1)/2/500e6*1e9),'response_span_ns':float((len(he)-1)/500e6*1e9),
       'equivalent_taps':len(he),'samples_grid':262145,'actual_pipeline_measured':False,
       'coefficient_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'filters').glob('*.csv'))}}
    assert f['ripple_db']<=.1 and f['stop_db']>=70 and f['equivalent_taps']==167
    dump('filter_metrics.json',f)
    r=read('resource_budget');jobs=int(np.count_nonzero(q1[:len(q1)//2]))*2+math.ceil(len(q2)/2)
    fir=32*jobs;other=sum(v['dsp'] for v in r['dsp_rows'][2:]);assert fir==1536 and fir+other==1932
    resource=dict(fir_dsp= fir,other_dsp=other,functional_dsp=fir+other,planning_dsp_25pct=math.ceil((fir+other)*1.25),
         device_dsp=r['device']['dsp48e2'],resource_is_arithmetic_not_synthesis=True,ram_capture_bytes=4*4*16384*8,
         ram_capture_example_ramb36=4*4*32,ram_total_planned=[760,820],high_order_calibration_not_in_baseline=True,
         fractional_delay_taps63_is_only_budget=True,fir_sensitivity=r['fir_sensitivity'])
    dump('resource_recalculation.json',resource)
    from models.numeric_model import packet_queue
    scenarios=[]
    for groups,prf,storage in [(1,1000,.8e9),(1,3300,.8e9),(4,1000,.8e9),(4,3300,2e9),(4,3300,.8e9)]:
        args=dict(duration=1.,fs_out=125e6,prf=prf,window=126e-6,groups=groups,banks=4,dma_rate=2.4e9,storage_rate=storage,
                  slots=512,slot_bytes=262144,samples_per_bank=16384)
        result=packet_queue(**args)
        result={k:v for k,v in result.items() if not k.startswith('trace')}
        result['assumptions']=args;scenarios.append(result)
    dump('queue_scenarios.json',{'status':'ASSUMED_SERVICE_EVENT_MODEL','not_full_three_range_selector_simulation':True,'scenarios':scenarios})
    return f,resource

def c_header_check():
    cc=shutil.which('cc') or shutil.which('gcc') or shutil.which('clang')
    if not cc:return dict(status='NOT_RUN',reason='C compiler unavailable; header generation checked only')
    src=r'''#include "calib_contract.h"
_Static_assert(CALIB_BANK_COUNT_BITS == 15, "count overflow");
_Static_assert(CALIB_FIR_CLOCK_HZ == 125000000, "FIR clock");
_Static_assert(CALIB_DMA_CLOCK_HZ == 200000000, "DMA clock");
_Static_assert(CALIB_MAX_RECORD_BYTES == 131216, "frame size");
_Static_assert(CALIB_RETURN_TOKEN_BYTES == 32, "token size");
int main(void) { return (CALIB_DMA_SLOT_BYTES > CALIB_MAX_RECORD_BYTES) ? 0 : 1; }
'''
    with tempfile.TemporaryDirectory(prefix='calib_header_') as td:
        p=Path(td)/'check.c';p.write_text(src);exe=Path(td)/'check'
        cmd=[cc,'-std=c11','-Wall','-Wextra','-Werror','-I',str(ROOT/'generated'),str(p),'-o',str(exe)]
        t=subprocess.run(cmd,capture_output=True,text=True)
        (OUT/'c_header_build.log').write_text(t.stdout+t.stderr)
        if t.returncode:raise RuntimeError(t.stderr)
        t=subprocess.run([str(exe)],capture_output=True,text=True);assert t.returncode==0
    return dict(status='PASS',compiler=Path(cc).name,scope='generated constants/offset definitions only; not PS drivers')

def main():
    start=time.time()
    run([sys.executable,'tools/generate_contracts.py','--check'],'generated_check.log')
    raw=run([sys.executable,'-m','unittest','discover','-s','tests','-v'],'tests_current.log')
    n=int(re.search(r'Ran (\d+) tests?',raw).group(1))
    static=static_checks();f,res=numeric_reports();c=c_header_check()
    open_gates=read('system_contract')['baseline_gates']
    summary={'status':'MERGED_DESIGN_AND_REFERENCE_CHECKS_PASS','tests_passed':n,'tests_failed':0,
             'static':static,'generated_C_compile':c,'hardware_ready':False,
             'unrun':['Vivado IP generation','RTL/xsim simulation','CDC/RAM timing','implementation/timing/power','Vitis/Linux board drivers','RFDC MTS and physicalRF bench'],
             'hardware_acceptance_items_not_run':len(read('verification_matrix')['tests']),
             'unresolved_inputs':open_gates,'filter_metrics':{k:f[k] for k in ['ripple_db','stop_db','group_delay_ns','response_span_ns']},
             'dsp_arithmetic':{k:res[k] for k in ['fir_dsp','functional_dsp','planning_dsp_25pct']},
             'environment':dict(python=platform.python_version(),numpy=np.__version__,scipy=scipy.__version__,system=platform.system()),
             'elapsed_s':round(time.time()-start,3),'verified_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
    dump('verification_summary.json',summary)
    (OUT/'验证结果.md').write_text(f'''# v0.5实际验证结果\n\n当前执行通过{n}项Python测试；16份合同JSON、系数CSV/COE、时钟/速率/尺寸、ABI偏移与寄存器范围已核对。\n\n生成C常量编译：{c['status']}。只编译常量头，不表示PS驱动实现。SystemVerilog常量仅做生成一致性检查，未运行Vivado。\n\nHB19+FIR75系数域纹波{f['ripple_db']:.6f}dB，阻带{f['stop_db']:.6f}dB，群延迟{f['group_delay_ns']:.0f}ns。优化FIR1536DSP、约定功能算量1932、25%规划2415；非综合结果。\n\n硬件验收{summary['hardware_acceptance_items_not_run']}项仍NOT_RUN。板卡/工具/native映射/阈值/检测上界/实现latency/持续服务率等待实际证据。\n\n测试含原RingBuffer28项、原数值13项，以及本版合并/四bank轮换/选择后释放/超窗/TX完整尾/代码生成等新增项；数量以实际日志为准。队列groups=1仅模拟选择后输出负载，不当作全三档状态机仿真。\n\n`merge_tests_before.log`、`model_boundary_tests_before.log`、`generated_tests_before.log`、`source_mapping_before.log`是合并前预期失败证据，不是当前失败；当前以`tests_current.log`为准。\n''',encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
