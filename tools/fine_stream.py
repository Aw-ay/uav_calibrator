"""Fine registered stream models. No access to unread RAM or full RAW storage."""
from collections import deque
from dataclasses import replace
from fine_fixed import FixedEdge, edge_pair_q16, _product, signed


class SampleCache:
 """32 logical H/V samples; natural word input, one sample retire and one peek.

 observe reads only current state and inputs. clock commits at the rising edge.
 Abort cancels this local cache only; upstream B reader still must drain its
 issued RAM requests before releasing the bank. rst is cold/quiescent reset.
 """
 def __init__(self):
  self.busy=False;self.q=deque();self.total=0;self.odd=0;self.accepted=0
  self.done=False;self.error=False;self.peek_valid=False;self.peek_found=False
  self.peek_data=0;self.peek_result_index=0

 def observe(self,i):
  enabled=not i.get('abort',0) and not i.get('rst',0)
  mask=i.get('word_mask',0);n=2 if mask==3 else 1
  valid=self.busy and bool(self.q) and enabled
  index,data=self.q[0] if valid else (0,0)
  return dict(job_ready=not self.busy and not self.peek_valid and enabled,
      word_ready=self.busy and self.accepted<self.total and len(self.q)+n<=32 and enabled,
      sample_valid=valid,sample_data=data,sample_index=index,
      sample_last=valid and index==self.total-1,occupancy=len(self.q),busy=self.busy,
      done=self.done,error=self.error,peek_req_ready=self.busy and enabled and
      (not self.peek_valid or i.get('peek_ready',0)),peek_valid=self.peek_valid and enabled,
      peek_found=self.peek_found,peek_data=self.peek_data,peek_result_index=self.peek_result_index)

 def clock(self,i):
  o=self.observe(i)
  if i.get('rst',0) or i.get('abort',0):self.__init__();return
  self.done=False;self.error=False
  # Snapshot peek before simultaneous writes/pops: registered read of old contents.
  if o['peek_req_ready'] and i.get('peek_req_valid',0):
   index=i.get('peek_index',0);self.peek_valid=True;self.peek_result_index=index
   self.peek_found=any(k==index for k,_ in self.q)
   self.peek_data=next((d for k,d in self.q if k==index),0)
  elif self.peek_valid and i.get('peek_ready',0):self.peek_valid=False
  if o['sample_valid'] and i.get('sample_ready',0):
   self.q.popleft()
   if o['sample_last']:self.busy=False;self.done=True
  if o['word_ready'] and i.get('word_valid',0):
   n=min(2,self.total-self.accepted)
   mask=2 if self.accepted==0 and self.odd else (1 if n==1 else 3)
   n=mask.bit_count()
   good=(i.get('word_mask',0)==mask and i.get('word_index',0)==self.accepted and
         bool(i.get('word_first',0))==(self.accepted==0) and
         bool(i.get('word_last',0))==(self.accepted+n==self.total))
   if not good:
    self.busy=False;self.q.clear();self.peek_valid=False;self.error=True
   else:
    data=i.get('word_data',0)
    for lane in range(2):
     if mask&(1<<lane):
      self.q.append((self.accepted,(data>>(64*lane))&((1<<64)-1)));self.accepted+=1
  if o['job_ready'] and i.get('job_valid',0):
   count=i.get('job_count',0)
   if not 1<=count<=16384:self.error=True
   else:
    self.busy=True;self.q.clear();self.total=count;self.odd=i.get('job_odd',0);self.accepted=0


class FinePass:
 """Causal schedule proof with 32 IQ samples, not a full RTL cycle equivalence.

 A logical sample is accepted per tick. At full occupancy one oldest sample is
 retired before accepting more. Brackets are evaluated only once k+4 has arrived
 (or EOF clips the support). Edge arithmetic is an ideal fixed numerical service
 whose configurable latency explicitly stalls reads AND retirement. Only local
 eight-power arrays are passed to that service; no whole-frame array is retained.
 The final LS/CORDIC is outside this proof: outputs are exact sufficient sums.
 """
 def __init__(self,count,*,coarse,noise,top_signal,edge_latency=33):
  if not 1<=count<=16384 or not 0<=coarse[0]<coarse[1]<=count or (not callable(edge_latency) and edge_latency<1):
   raise ValueError('Fine geometry/latency')
  self.total=count;self.coarse=coarse;self.noise=noise;self.top=top_signal
  self.latency=edge_latency;self.threshold=[noise[p]+(top_signal[p]>>1) for p in range(2)]
  self.buffer=deque();self.accepted=0;self.retired=0;self.peak_samples=0
  self.next_k=0;self.busy_cycles=0;self.pending=[];self.edge_stall_cycles=0
  self.edges=[[FixedEdge(quality=2),FixedEdge(quality=4)] for _ in range(2)]
  self.crossings=[[0,0] for _ in range(2)];self.finished=[[False,False] for _ in range(2)]
  self.bins=[[[0]*6 for _ in range(8)] for _ in range(2)]
  self.energy=[0,0];self.body_count=[0,0];self.prev=[None,None];self.hv=[0]*5
  self.done=False;self.result=None

 def _mark_finished(self):
  for p in range(2):
   for w in range(2):
    if self.next_k>min(self.total-2,self.coarse[w]+8):self.finished[p][w]=True

 def _apply_pending(self):
  for p,w,e in self.pending:
   old=self.edges[p][w]
   if e.valid:
    if w==1 or not old.valid:self.edges[p][w]=e
   elif not old.valid and (w==0 or self.crossings[p][w]==1):self.edges[p][w]=e
  self.pending=[];self._mark_finished()

 def _candidate(self,k):
  # All lookup indices are bounded by already accepted samples in the local FIFO.
  first=max(0,k-3);last=min(self.total-1,k+4)
  wanted=any(max(0,c-8)<=k<=min(self.total-2,c+8) for c in self.coarse)
  service_cycles=0
  if wanted:
   local=[row for row in self.buffer if first<=row[0]<=last]
   assert len(local)==last-first+1 and last<self.accepted,('unavailable local support',k)
   for p in range(2):
    powers=[sum(x*x for x in row[1][p]) for row in local]
    t=self.threshold[p];offset=k-first
    for w in range(2):
     if not max(0,self.coarse[w]-8)<=k<=min(self.total-2,self.coarse[w]+8):continue
     p0,p1=powers[offset:offset+2]
     crosses=p0<t<=p1 if w==0 else p0>=t>p1
     if not crosses:continue
     self.crossings[p][w]+=1
     e=edge_pair_q16(powers,offset,t,self.noise[p],w==0)
     if e.valid:e=replace(e,index_q16=e.index_q16+(first<<16),two_q16=e.two_q16+(first<<16),fit_q16=e.fit_q16+(first<<16))
     self.pending.append((p,w,e))
     if callable(self.latency):service_cycles+=self.latency(powers,offset,k,t,self.noise[p],w==0)
  self.next_k=k+1
  if self.pending:self.busy_cycles=service_cycles if callable(self.latency) else self.latency
  else:self._mark_finished()

 def _included(self,p,n):
  # Never retroactively edit emitted sums. Before fall is known, only its
  # guaranteed prefix is admitted; 32 slots must suffice to resolve uncertainty.
  if self.top[p]==0 or self.top[p]<4*self.noise[p]:return False
  if not self.finished[p][0]:
   assert n<max(0,self.coarse[0]-8)+4,('unresolved rise at retirement',p,n)
   return False
  rise,fall=self.edges[p]
  if not rise.valid:return False
  if n<((rise.index_q16+65535)>>16)+4:return False
  if not self.finished[p][1]:
   assert n<=max(0,self.coarse[1]-8)-4,('unresolved fall at retirement',p,n)
   return True
  return fall.valid and rise.index_q16<fall.index_q16 and n<=(fall.index_q16>>16)-4

 def _retire(self):
  n,iq=self.buffer.popleft();assert n==self.retired;self.retired+=1
  active=[self._included(p,n) for p in range(2)]
  for p in range(2):
   if not active[p]:self.prev[p]=None;continue
   value=iq[p];power=sum(x*x for x in value)
   self.energy[p]+=power;self.body_count[p]+=1;assert self.energy[p]<(1<<46)
   if self.prev[p] is not None:
    pn,pv=self.prev[p];assert pn==n-1
    re,im=_product(value,pv)
    a,b=self.coarse;segment=max(0,min(7,((2*n-1-2*a)*8)//(2*(b-a))))
    row=self.bins[p][segment]
    row[0]=signed(row[0]+re,48);row[1]=signed(row[1]+im,48)
    row[2]+=2*n-1;row[3]+=1;row[4]+=power;row[5]+=sum(x*x for x in pv)
   self.prev[p]=(n,value)
  if all(active):
   re,im=_product(*iq);self.hv[0]=signed(self.hv[0]+re,48);self.hv[1]=signed(self.hv[1]+im,48)
   self.hv[2]+=sum(x*x for x in iq[0]);self.hv[3]+=sum(x*x for x in iq[1]);self.hv[4]+=1

 def _finish(self):
  result={}
  for p,key in enumerate(['h','v']):
   rise,fall=self.edges[p];q=rise.quality|fall.quality
   if any(c>1 for c in self.crossings[p]):q|=16|32
   if self.top[p]==0 or self.top[p]<4*self.noise[p]:q|=1
   valid=rise.valid and fall.valid and rise.index_q16<fall.index_q16 and not q&1
   result[key]=dict(rise=rise,fall=fall,edge_quality=q,timing_valid=valid,
     body_first=((rise.index_q16+65535)>>16)+4 if valid else 0,
     body_last=(fall.index_q16>>16)-4 if valid else -1,
     bins=self.bins[p] if valid else [[0]*6 for _ in range(8)],
     energy=self.energy[p] if valid else 0,count=self.body_count[p] if valid else 0)
  result['hv_sums']=self.hv if all(result[k]['timing_valid'] for k in ['h','v']) else [0]*5
  self.result=result;self.done=True

 def tick(self,sample=None,*,retire_ready=True):
  if self.done:return False
  if self.busy_cycles:
   self.edge_stall_cycles+=1;self.busy_cycles-=1
   if self.busy_cycles==0:self._apply_pending()
   return False
  if self.accepted==self.total and self.next_k<self.total-1:
   self._candidate(self.next_k);return False
  if len(self.buffer)==32 or self.accepted==self.total:
   if retire_ready and self.buffer:self._retire()
   if not self.buffer and self.accepted==self.total:self._mark_finished();self._finish()
   return False
  if sample is not None:
   for values in sample:
    for x in values:signed(x,16)
   n=self.accepted;self.buffer.append((n,tuple(tuple(v) for v in sample)));self.accepted+=1
   self.peak_samples=max(self.peak_samples,len(self.buffer))
   if n>=4:self._candidate(n-4)
   return True
  return False
