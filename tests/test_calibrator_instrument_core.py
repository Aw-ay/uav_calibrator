from pathlib import Path
import subprocess,tempfile,sys,re,struct
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_calibrator_dataplane_system import sources,vectors
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import decode_frame
directory=vectors()
with tempfile.TemporaryDirectory() as tmp:
    sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_calibrator_instrument_core','-o',sim,*sources,'tb/system/tb_calibrator_instrument_core.sv'],cwd=ROOT,capture_output=True,text=True,timeout=120)
    assert p.returncode==0,p.stdout+p.stderr
    assert not any(term in p.stderr for term in ['implicit definition','dangling input','expects']),p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=240)
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
    powers=[(hi*hi+hq*hq,vi*vi+vq*vq) for hi,hq,vi,vq in samples]
    assert (tag,flags,pid,cfg,toa,width,selected)==(65537,31,header['pulse_id'],header['config_id'],gsc,(len(samples)-3-4)*4,header['range_id'])
    assert epoch==0 and peak==max(max(v) for v in powers) and energy==sum(sum(v) for v in powers)
    assert pdw[56:]==bytes(8)
    print('PASS independent PDW decode and actual RAW H/V energy peak onset width identity')
