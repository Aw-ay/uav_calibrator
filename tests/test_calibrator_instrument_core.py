from pathlib import Path
import subprocess,tempfile,sys,re,struct
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources,vectors
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import decode_frame
source_vectors=vectors()
directory=ROOT/'build/fine_instrument_vectors';directory.mkdir(parents=True,exist_ok=True)
(directory/'headers.hex').write_bytes((source_vectors/'headers.hex').read_bytes())
with tempfile.TemporaryDirectory() as tmp:
    sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_calibrator_instrument_core','-o',sim,*sources,'tb/system/tb_calibrator_instrument_core.sv'],cwd=ROOT,capture_output=True,text=True,timeout=120)
    assert p.returncode==0,p.stdout+p.stderr
    assert not any(term in p.stderr for term in ['implicit definition','dangling input','expects']),p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=1200)
    (ROOT/'reports/calibrator_instrument_core.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS instrument core' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
    frame=bytes.fromhex((directory/'instrument_frame.hex').read_text())
    header,samples=decode_frame(frame)  # independent ABI, header and payload CRC checks
    onset,gsc=map(int,re.search(r'ONSET (\d+) (\d+)',p.stdout).groups())
    stop=int(re.search(r'EOP (\d+)',p.stdout)[1])
    observed={int(seq):(int(ticks),struct.unpack('<hhhh',int(word,16).to_bytes(8,'little'))) for seq,ticks,word in (line.split() for line in (directory/'instrument_samples.txt').read_text().splitlines())}
    assert header['physical_adc_mask']==0x22,header
    assert header['pulse_id']==1 and header['config_id']==7 and header['range_id']==1
    assert header['gsc_first']==gsc-12 and header['sample_count']==stop-onset+3
    assert samples==[observed[seq][1] for seq in range(onset-3,stop)]
    assert all(observed[seq][0]==header['gsc_first']+4*i for i,seq in enumerate(range(onset-3,stop)))
    print('PASS independent RAW decode CRC and every real FIR sample / GSC / PRE-body-POST boundary')
    pdw_words=[int(x,16) for x in (directory/'instrument_pdw.hex').read_text().split()]
    assert len(pdw_words)==20 and pdw_words[:2]==[1,0]
    pdw=b''.join(x.to_bytes(4,'little') for x in pdw_words[4:])
    tag,flags,pid,epoch,cfg,toa,width,peak,energy,selected=struct.unpack_from('<IIQQIQIIQI',pdw)
    body_end=int(re.search(r'BODY_END (\d+)',p.stdout)[1])
    body=[observed[seq][1] for seq in range(onset,body_end)]
    powers=[(hi*hi+hq*hq,vi*vi+vq*vq) for hi,hq,vi,vq in body]
    assert (tag,flags,pid,cfg,toa,width,selected)==(65537,31,header['pulse_id'],header['config_id'],gsc,len(body)*4,header['range_id'])
    assert epoch==0 and peak==max(max(v) for v in powers) and energy==sum(sum(v) for v in powers)
    assert pdw[56:]==bytes(8)
    print('PASS independent PDW decode and actual body H/V energy peak onset width identity; no A-port statistics scan')
    # Fine is checked against the actual FIR samples saved before bank analysis.
    # The batch oracle is host-only verification; it supplies no masks/edges to RTL.
    from fine_fixed import measure_fixed
    from fine_pdw_codec import decode as decode_fine
    full_samples={int(seq):int(word,16) for seq,word in (line.split() for line in (directory/'instrument_fine_samples.txt').read_text().splitlines())}
    fine_jobs=[int(x,16) for x in re.findall(r'FINE_JOB ([0-9a-fA-F]+)',p.stdout)]
    fine_records=[decode_fine(bytes.fromhex(x)[::-1]) for x in (directory/'instrument_fine.hex').read_text().splitlines()]
    frozen_noise=int(re.search(r'FINE_ONSET_NOISE ([0-9a-fA-F]+)',p.stdout)[1],16)
    assert len(fine_jobs)==len(fine_records)==3
    def bits(v,lo,w):return (v>>lo)&((1<<w)-1)
    for job,record in zip(fine_jobs,fine_records):
        bank=bits(job,0,4);group=bank//4;count=bits(job,18,15);coarse=(bits(job,33,15),bits(job,48,15))
        assert bank%4==0 and count==header['sample_count'] and coarse==(3,3+len(body))
        assert bits(job,4,14)==((onset-3)&16383)
        raw=[struct.unpack('<hhhh',bits(full_samples[seq],group*64,64).to_bytes(8,'little')) for seq in range(onset-3,stop)]
        iq=([r[:2] for r in raw],[r[2:] for r in raw])
        noises=tuple(bits(job,63+32*k,32) for k in range(2));tops=tuple(bits(job,127+32*k,32) for k in range(2))
        peaks=tuple(bits(job,191+32*k,32) for k in range(2))
        known=tuple(bool(bits(job,255+k,1)) for k in range(2));good=tuple(bool(bits(job,257+k,1)) for k in range(2))
        assert noises==tuple(bits(frozen_noise,(group+3*k)*32,32) for k in range(2))
        assert known==tuple(bool(bits(frozen_noise,192+group+3*k,1)) for k in range(2))
        for pol in range(2):
            powers=[i*i+q*q for i,q in iq[pol][coarse[0]:coarse[1]]]
            net=[max(0,x-noises[pol]) for x in powers]
            assert peaks[pol]==max(powers) and tops[pol]==max((sum(net[n-3:n+1])//4 for n in range(3,len(net))),default=0)
        expected=measure_fixed(*iq,noise=noises,top_signal=tops,coarse=coarse,source_good=good,noise_known=known)
        assert (record['pulse_id'],record['owner_epoch'],record['generation'],record['config_id'],record['range_id'],record['bank_id'],record['selected'],record['gsc_first'])==(1,0,1,7,group+1,0,int(group==0),header['gsc_first'])
        mask=flags=edgeq=specq=0
        for pol,key in enumerate(['h','v']):
            q=expected[key];spec=q['spectral'];mask|=int(q['timing_valid'])<<pol;mask|=int(spec['valid'])<<(pol+2)
            flags|=int(q['snr_saturated'])<<pol;edgeq|=q['edge_quality']<<(16*pol);specq|=spec['quality']<<(8*pol)
            for name,value in [('rise_index_q16',q['rise'].index_q16),('fall_index_q16',q['fall'].index_q16),('peak_power',peaks[pol]),('mean_body_power',q['mean_body_power']),('residual_frequency_hz',spec.get('frequency_hz',0)),('chirp_rate_hz_per_s',spec.get('chirp_hz_per_s',0)),('snr_q16',q['snr_q16'])]:
                assert record[key+'_'+name]==value,(group,key,name,record[key+'_'+name],value)
        mask|=int(expected['hv']['valid'])<<4;specq|=expected['hv']['quality']<<16
        assert (record['channel_valid_mask'],record['flags'],record['edge_quality'],record['spectral_quality'],record['hv_phase_q31_turn'])==(mask,flags,edgeq,specq,expected['hv'].get('phase_q31',0))
    assert {r['range_id'] for r in fine_records}=={1,2,3}
    print('PASS independent three-range Fine PDW decode: real FIR RAW, frozen onset noise, TOP4, body peak, all numeric and identity fields')
