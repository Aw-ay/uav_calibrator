"""D05 bit-width-bounded, causal reference; not an implemented PL block.

One clock() is one RF clock, including bad/missing samples. Six powers are in
H_HIGH/H_MID/H_LOW/V_HIGH/V_MID/V_LOW order. End events are supplied only when
the detector actually announces them, never from a future waveform oracle.
The fixed 272-cycle delay reserves 256 hold samples plus 16 cycles for producer
and arithmetic transport. Integration must prove that transport bound separately.
"""
from collections import deque
from copy import deepcopy

class OnlineStatistics:
    delay=272
    slots=4
    def __init__(self):
        self.contexts={}
        self.pending=deque()
        self.previous_seq=None
        self.last_committed=None

    def start(self,key,onset,noise,hold):
        if (key in self.contexts or len(self.contexts)==self.slots or not 1<=hold<=256
            or not 0<=onset<2**64 or len(noise)!=6 or any(not 0<=x<2**32 for x in noise)
            or (self.last_committed is not None and onset<=self.last_committed)):
            return False
        self.contexts[key]=dict(onset=onset,end=None,noise=tuple(noise),hold=hold,
            count=0,energy=[0]*6,peak=[0]*6,top_signal=[0]*6,
            history=[deque(maxlen=4) for _ in range(6)],bad=0,error=0,result=None)
        return True

    def _finish(self,c):
        c['result']={k:tuple(c[k]) if isinstance(c[k],list) else c[k]
                     for k in ('count','energy','peak','top_signal','bad','error')}
        c['result']['p50']=tuple(c['noise'][i]+c['top_signal'][i]//2 for i in range(6))
        c['result']['top_complete']=c['count']>=4

    def end(self,key,end):
        c=self.contexts.get(key)
        if c is None or c['end'] is not None or c['result'] is not None:
            return False
        c['end']=end
        if not c['onset']<end<2**64 or end-c['onset']>16384:
            c['error']|=1
        if self.last_committed is not None and end<=self.last_committed:
            c['error']|=2
        if c['error']:
            c['bad']=0x3f
            self._finish(c)
        return True

    def clock(self,seq,power,good=0x3f,valid=True):
        assert 0<=seq<2**64 and len(power)==6 and all(0<=p<=2**31 for p in power)
        gap=self.previous_seq is not None and seq!=self.previous_seq+1
        self.previous_seq=seq
        if gap:
            for c in self.contexts.values():
                if c['result'] is None:
                    c['error']|=8;c['bad']=0x3f;self._finish(c)
        bad=(~good)&0x3f if valid and not gap else 0x3f
        self.pending.append((seq,tuple(power),bad))
        if len(self.pending)<=self.delay:
            return
        seq,power,bad=self.pending.popleft()
        self.last_committed=seq
        for c in self.contexts.values():
            if c['result'] is not None or seq<c['onset']:
                continue
            if c['end'] is not None and seq>=c['end']:
                self._finish(c)
                continue
            if c['count']==16384:
                c['error']|=4;c['bad']=0x3f;self._finish(c)
                continue
            c['count']+=1;c['bad']|=bad
            for lane in range(6):
                p=power[lane]
                c['energy'][lane]+=p
                assert c['energy'][lane]<2**46
                c['peak'][lane]=max(c['peak'][lane],p)
                history=c['history'][lane]
                history.append(max(p-c['noise'][lane],0))
                if len(history)==4:
                    c['top_signal'][lane]=max(c['top_signal'][lane],sum(history)//4)

    def peek(self,key):
        c=self.contexts.get(key)
        return None if c is None else deepcopy(c['result'])

    def pop(self,key):
        if key not in self.contexts or self.contexts[key]['result'] is None:
            return False
        del self.contexts[key]
        return True
