"""Reproducible algorithmic models; NOT an RFDC, AXI, DDR or RTL simulator.

IQ paths are real columns with independent state. Frequencies are Hz, capacity is
bytes, service rate is bytes/s. Queue service rates and stalls are assumptions.
"""
from __future__ import annotations
import math
import heapq
import csv
from pathlib import Path
import numpy as np
from scipy import signal

COEFF_FRAC=17
STOP_WEIGHT=(10**(.1/20)-1)/(10**(.1/20)+1)/10**(-60/20)

def design_general(taps:int, fs:float, fp:float, stop:float)->dict:
    if taps<3 or taps%2!=1 or not 0<fp<stop<fs/2:
        raise ValueError('Require odd taps and 0<fp<stop<fs/2')
    h=signal.remez(taps,[0,fp,stop,fs/2],[1,0],weight=[1,STOP_WEIGHT],
                    fs=fs,grid_density=32,maxiter=200)
    h=h/h.sum()  # remove nominal DC gain; q17 quantization follows
    q=np.rint(h*2**COEFF_FRAC).astype(np.int64)
    if np.max(np.abs(q))>=2**17:raise OverflowError('Coefficient does not fit signed18')
    return dict(taps=taps,fs=fs,fp=fp,stop=stop,kind='GENERAL',q=q,h_float=h,
                decimation=2,coefficient_bits=18,coefficient_frac=COEFF_FRAC)

def design_halfband(taps:int, fs:float, fp:float)->dict:
    if taps%4!=3 or not 0<fp<fs/4:raise ValueError('Halfband N=4m+3 required')
    stop=fs/2-fp
    h=signal.remez(taps,[0,fp,stop,fs/2],[1,0],weight=[1,1],fs=fs,
                   grid_density=32,maxiter=200)
    c=taps//2;h[np.arange(taps)%2==c%2]=0;h[c]=.5
    q=np.rint(h*2**COEFF_FRAC).astype(np.int64)
    return dict(taps=taps,fs=fs,fp=fp,stop=stop,kind='HALFBAND',q=q,h_float=h,
                decimation=2,coefficient_bits=18,coefficient_frac=COEFF_FRAC)

def recommended_stages()->list[dict]:
    """Load frozen delivered integer coefficients; never silently redesign a profile."""
    root=Path(__file__).resolve().parents[1]
    out=[]
    for k,taps,fs,fp,stop,kind in [(1,19,500e6,62.5e6,187.5e6,'HALFBAND'),
                                  (2,75,250e6,50e6,62.5e6,'GENERAL')]:
        with (root/'filters'/f'RX_STAGE{k}.csv').open(encoding='utf-8') as f:
            q=np.array([int(row['integer']) for row in csv.DictReader(f)],dtype=np.int64)
        if len(q)!=taps or np.any(q<-(1<<17)) or np.any(q>=(1<<17)):
            raise ValueError('Frozen coefficient file length/range mismatch')
        out.append(dict(taps=taps,fs=fs,fp=fp,stop=stop,kind=kind,q=q,h_float=q/2**17,
                        decimation=2,coefficient_bits=18,coefficient_frac=17))
    return out

def equivalent(stages:list[dict],quantized:bool=True)->np.ndarray:
    h=np.ones(1);stride=1
    for st in stages:
        a=st['q']/2**COEFF_FRAC if quantized else st['h_float']
        b=np.zeros((len(a)-1)*stride+1);b[::stride]=a
        h=np.convolve(h,b);stride*=st['decimation']
    return h

def metrics(h:np.ndarray,fs:float,fp:float,stop:float,points:int=262145)->dict:
    f,H=signal.freqz(h,worN=points,include_nyquist=True,fs=fs)
    _,edge=signal.freqz(h,worN=np.array([fp,stop]),fs=fs)
    pb=np.r_[np.abs(H[f<=fp]),abs(edge[0])]
    sb=np.r_[np.abs(H[f>=stop]),abs(edge[1])]
    return dict(ripple_db=float(20*np.log10(pb.max()/pb.min())),
        stop_db=float(-20*np.log10(sb.max())),dc_gain_db=float(20*np.log10(abs(h.sum()))),
        pass_min_db=float(20*np.log10(pb.min())),pass_max_db=float(20*np.log10(pb.max())),
        group_delay_ns=float((len(h)-1)/2/fs*1e9),
        noise_enbw_hz=float(fs*np.sum(h*h)/np.sum(h)**2),grid_points=points,
        l1_norm=float(np.sum(np.abs(h))))

def round_shift(a:np.ndarray,bits:int)->np.ndarray:
    a=np.asarray(a,dtype=np.int64)
    if bits<0:raise ValueError('Nonnegative right shift required')
    if bits==0:return a.copy()
    den=1<<bits;floor=np.floor_divide(a,den);rem=a-floor*den;half=den>>1
    return floor+((rem>half)|((rem==half)&((floor&1)!=0))).astype(np.int64)

class FixedDecimator:
    """Exact int64 MAC, 48-bit overflow check, ties-even rounding, signed clamp.

    First retained sample has global input index 0. State/phase survive all
    process() boundaries. Processing a chunk does not insert a time gap.
    """
    def __init__(self,q:np.ndarray,decimation:int,frac:int,width:int,paths:int):
        self.q=np.asarray(q,dtype=np.int64)
        if decimation<1 or paths<1 or width<2:raise ValueError('Invalid format')
        self.D=decimation;self.frac=frac;self.width=width;self.paths=paths
        self.history=np.zeros((len(self.q)-1,paths),np.int64);self.count=0
        self.clips=0;self.max_acc=0
    def process(self,x:np.ndarray)->np.ndarray:
        x=np.asarray(x,dtype=np.int64)
        if x.ndim!=2 or x.shape[1]!=self.paths:raise ValueError('Expected samples x paths')
        if len(x)==0:return np.zeros((0,self.paths),np.int64)
        cat=np.concatenate((self.history,x),axis=0)
        windows=np.lib.stride_tricks.sliding_window_view(cat,len(self.q),axis=0)
        first=(-self.count)%self.D
        acc=windows[first::self.D]@self.q[::-1]
        if acc.size:
            self.max_acc=max(self.max_acc,int(np.max(np.abs(acc))))
            if np.any(acc>=2**47) or np.any(acc<-(2**47)):
                raise OverflowError('48-bit accumulator overflow')
        y=round_shift(acc,self.frac);lo=-(1<<(self.width-1));hi=(1<<(self.width-1))-1
        self.clips+=int(np.count_nonzero((y<lo)|(y>hi)))
        self.history=cat[-(len(self.q)-1):].copy();self.count+=len(x)
        return np.clip(y,lo,hi)

def run_fixed_rx(x:np.ndarray,stages:list[dict])->tuple[np.ndarray,dict]:
    y=np.asarray(x,dtype=np.int64);stats=[]
    for st in stages:
        ob=FixedDecimator(st['q'],st['decimation'],COEFF_FRAC,24,y.shape[1])
        y=ob.process(y);stats.append(dict(clips=ob.clips,max_acc=ob.max_acc))
    return y,dict(stages=stats)

def run_packed_rx(x:np.ndarray,stages:list[dict],spc:int)->np.ndarray:
    x=np.asarray(x,dtype=np.int64)
    if len(x)%spc:raise ValueError('Sample count must be divisible by SPC')
    beats=x.reshape(-1,spc,x.shape[1])
    objects=[FixedDecimator(st['q'],st['decimation'],COEFF_FRAC,24,x.shape[1]) for st in stages]
    parts=[];b=0;sizes=[1,3,31,2,129,7,64];k=0
    while b<len(beats):
        size=sizes[k%len(sizes)];k+=1
        chunk=beats[b:b+size].reshape(-1,x.shape[1]);b+=size
        for ob in objects:chunk=ob.process(chunk)
        if len(chunk):parts.append(chunk)
    return np.concatenate(parts,axis=0)

def run_fixed_tx(x:np.ndarray,stages:list[dict])->tuple[np.ndarray,dict]:
    """Two L2 stages; q17 prototype is used with frac16 to supply L=2 gain."""
    z=np.asarray(x,dtype=np.int64);stats=[]
    for st in stages[::-1]:
        u=np.zeros((2*len(z),z.shape[1]),np.int64);u[::2]=z
        ob=FixedDecimator(st['q'],1,COEFF_FRAC-1,24,z.shape[1]);z=ob.process(u)
        stats.append(dict(clips=ob.clips,max_acc=ob.max_acc))
    return z,dict(stages=stats)

def finish_service(start:float,nbytes:float,rate:float,period:float=0.,stall:float=0.)->float:
    """Constant service interrupted on [k*period,k*period+stall), k>=1."""
    if nbytes<0 or rate<=0 or stall<0 or (period and stall>=period):raise ValueError('Invalid service')
    if period<=0 or stall==0:return start+nbytes/rate
    cur=start;left=nbytes/rate
    while left>1e-15:
        cycle=math.floor((cur+1e-14)/period)
        if cycle>=1 and cur < cycle*period+stall-1e-14:
            cur=cycle*period+stall
        next_stall=(math.floor((cur+1e-14)/period)+1)*period
        free=max(0.,next_stall-cur)
        if left<=free+1e-15:return cur+left
        left-=free;cur=next_stall+stall
    return cur

def continuous_queue(arrival_rate:float,service_rate:float,capacity:float,duration:float,
                     dt:float=8e-9)->dict:
    """Fluid FIFO sampled at dt; service jitter excluded in this submodel."""
    if min(arrival_rate,service_rate,capacity,duration,dt)<=0:raise ValueError('Positive values required')
    t=np.arange(1,math.ceil(duration/dt)+1)*dt
    offered=np.maximum(0.,(arrival_rate-service_rate)*t)
    idx=np.flatnonzero(offered>capacity)
    return dict(first_overflow_s=float(t[idx[0]]) if len(idx) else None,
        final_backlog_bytes=float(min(offered[-1],capacity)),
        offered_final_backlog_bytes=float(offered[-1]),
        lost_bytes=float(max(offered[-1]-capacity,0)),
        stable=bool(arrival_rate<=service_rate),dt_s=dt)

def packet_queue(*,duration:float,fs_out:float,prf:float,window:float,groups:int,banks:int,
    dma_rate:float,storage_rate:float,slots:int,slot_bytes:int=262144,
    dma_stall:float=0.,dma_period:float=0.,storage_stall:float=0.,storage_period:float=0.,
    replay_delay:float=0.,rearm:float=2e-6,record_every:int=1,aux_offset:float=0.,samples_per_bank:int=16384)->dict:
    """Coupled finite capture-bank -> SG slots -> storage event model.

    One record/group/pulse, one serial DMA writer, one serial storage writer.
    A DDR slot is reserved before DMA starts and released after storage finishes.
    Bank release requires both DMA transfer and local replay to finish, then rearm.
    New capture is dropped when no bank is free; RFDC sampling NEVER stops.
    Record skipping is intentional retention decimation, not sample decimation.
    Fixed 144-byte header+trailer; extra 2us DMA/descriptor gap per record.
    All input service rates are hypothetical effective payload rates.
    """
    if min(duration,fs_out,prf,window,groups,banks,dma_rate,storage_rate,slots,record_every)<=0:
        raise ValueError('Invalid queue arguments')
    ns=int(math.ceil(fs_out*window-1e-8));record=ns*8+144
    if samples_per_bank<1 or ns>samples_per_bank:raise ValueError('Record exceeds capture bank sample capacity')
    if record>slot_bytes:raise ValueError('Record exceeds its DMA slot')
    events=[];total_pulses=int(math.ceil(duration*prf-1e-12));planned=0
    for p in range(total_pulses):
        if p%record_every:continue
        for g in range(groups):
            t=p/prf+(aux_offset if g==groups-1 else 0)
            if t<duration:
                heapq.heappush(events,(t,0,g,p,-1,t));planned+=1
    free=np.zeros((groups,banks));dma_available=0.;storage_available=0.
    slot_finishes=[];lost=0;accepted=0;highwater=0;latencies=[];slot_event=[]
    per_group_lost=[0]*groups;trace=[];max_busy=[0]*groups
    while events:
        t,typ,g,p,b,start=heapq.heappop(events)
        if typ==0:
            ids=np.flatnonzero(free[g]<=t+1e-14)
            if not len(ids):lost+=1;per_group_lost[g]+=1;continue
            b=int(ids[0]);free[g,b]=np.inf;accepted+=1
            max_busy[g]=max(max_busy[g],int(np.count_nonzero(free[g]>t)))
            heapq.heappush(events,(t+window,1,g,p,b,t))
        else:
            ds=max(t,dma_available)
            while slot_finishes and slot_finishes[0]<=ds+1e-14:heapq.heappop(slot_finishes)
            while len(slot_finishes)>=slots:
                ds=max(ds,heapq.heappop(slot_finishes))
                while slot_finishes and slot_finishes[0]<=ds+1e-14:heapq.heappop(slot_finishes)
            de=finish_service(ds,record,dma_rate,dma_period,dma_stall)
            dma_available=de+2e-6
            ss=max(de,storage_available)
            se=finish_service(ss,record,storage_rate,storage_period,storage_stall)
            storage_available=se;heapq.heappush(slot_finishes,se)
            highwater=max(highwater,len(slot_finishes));slot_event.extend([(ds,1),(se,-1)])
            free[g,b]=max(de,start+replay_delay+window)+rearm
            latencies.append(de-t)
            if g==0:trace.append((start,free[g,b]-start))
    occupancy=0;sampled=[]
    for t,delta in sorted(slot_event,key=lambda a:(a[0],a[1])):
        occupancy+=delta;sampled.append((t,occupancy))
    return dict(planned_records=planned,accepted_records=accepted,lost_records=lost,
        loss_fraction=lost/planned if planned else 0.,per_group_lost=per_group_lost,
        record_bytes=record,sample_count=ns,samples_per_bank=samples_per_bank,slot_bytes=slot_bytes,slots=slots,
        ring_allocation_bytes=slots*slot_bytes,ring_payload_capacity_bytes=slots*record,
        max_reserved_slots=highwater,max_reserved_slot_bytes=highwater*slot_bytes,
        offered_record_bytes_per_second=groups*prf/record_every*record,
        accepted_bytes=accepted*record,
        max_dma_wait_and_transfer_s=float(max(latencies,default=0)),
        max_banks_busy=max_busy,simulated_arrival_duration_s=duration,
        all_accepted_storage_finished_s=storage_available,
        replay_delay_s=replay_delay,trace_bank_hold=np.array(trace),
        trace_slot_occupancy=np.array(sampled))


def run_fixed_tx_complete(x:np.ndarray,stages:list[dict])->tuple[np.ndarray,dict]:
    """Flush the two-stage PL interpolation tail; not upstream calibration/RFDC tails.

    run_fixed_tx intentionally returns only the time span supplied by its input.
    A normal burst must append zeros; hardware must also drain its own fixed latency.
    """
    if len(stages)!=2 or any(st['decimation']!=2 for st in stages):
        raise ValueError('Tail wrapper currently supports two L2 stages only')
    x=np.asarray(x,dtype=np.int64)
    if x.ndim!=2 or not len(x):raise ValueError('Require nonempty samples x real paths')
    high_span=(len(stages[0]['q'])-1)+2*(len(stages[1]['q'])-1)
    zeros=math.ceil(high_span/4)
    y,stats=run_fixed_tx(np.pad(x,((0,zeros),(0,0))),stages)
    stats=dict(stats,pl_tail_zero_inputs=zeros,input_samples=len(x),
               output_samples=len(y),includes_implementation_pipeline=False,
               includes_calibration_or_RFDC_tails=False)
    return y,stats
