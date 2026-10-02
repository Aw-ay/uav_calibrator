"""D06 floating-point mathematical reference. NOT cycle- or bit-accurate RTL.

Inputs are frozen RAW and causal online priors. One-pass feasibility is evaluated
separately; batch lists and atan2 here are deliberately algorithm truth only.
Frequency is the fitted residual frequency at RAW sample zero (gsc_first).
"""
from dataclasses import dataclass,field
import cmath,math

EDGE_LOW_SNR=1<<0
EDGE_NO_RISE=1<<1
EDGE_NO_FALL=1<<2
EDGE_FLAT=1<<3
EDGE_MULTI=1<<4
EDGE_RINGING=1<<5
EDGE_LOCAL=1<<6
EDGE_BAD_SOURCE=1<<7
SPEC_TOO_SHORT=1<<0
SPEC_SEGMENTS=1<<1
SPEC_ZERO=1<<2
SPEC_AMBIGUOUS=1<<3
SPEC_BAD_EDGES=1<<4
SPEC_COHERENCE=1<<5

@dataclass(frozen=True)
class FineConfig:
 sample_rate: int=125_000_000
 search_radius: int=8
 fit_points: int=8
 minimum_fit_points: int=4
 body_guard: int=4
 minimum_body: int=9
 segments: int=8
 minimum_snr: float=4.0
 maximum_segment_delta_turn: float=.25
 maximum_frequency_fraction: float=.49

@dataclass
class Edge:
 index: float=0.0
 two_point: float=0.0
 linear_fit: float=0.0
 variance_two: float=0.0
 variance_fit: float=0.0
 valid: bool=False
 quality: int=0
 crossings: int=0

@dataclass
class Polarization:
 rise: Edge=field(default_factory=Edge)
 fall: Edge=field(default_factory=Edge)
 timing_valid: bool=False
 spectral_valid: bool=False
 threshold_power: float=0
 body_first: int=0
 body_last: int=-1
 mean_body_power: float=0
 snr: float=0
 frequency_hz: float=0
 chirp_hz_per_s: float=0
 edge_quality: int=0
 spectral_quality: int=0
 segment_centers: tuple=()

@dataclass
class Result:
 h: Polarization
 v: Polarization
 hv_valid: bool=False
 hv_phase_turn: float=0
 hv_first: int=0
 hv_last: int=-1


def _line(x,y):
 n=len(x);xm=sum(x)/n;ym=sum(y)/n
 xx=sum((a-xm)**2 for a in x)
 if xx==0:raise ValueError('degenerate regression centers')
 slope=sum((a-xm)*(b-ym) for a,b in zip(x,y))/xx
 return ym-slope*xm,slope,xm,xx


def _edge(power,threshold,noise,coarse,rising,cfg):
 lo=max(0,coarse-cfg.search_radius);hi=min(len(power)-2,coarse+cfg.search_radius)
 candidates=[k for k in range(lo,hi+1) if (power[k]<threshold<=power[k+1] if rising else power[k]>=threshold>power[k+1])]
 if not candidates:return Edge(quality=EDGE_NO_RISE if rising else EDGE_NO_FALL)
 order=candidates if rising else candidates[::-1]
 failed=EDGE_LOCAL
 for k in order:
  slope=power[k+1]-power[k]
  if slope==0:failed=EDGE_FLAT;continue
  frac=(threshold-power[k])/slope;e2=k+frac
  first=max(0,k-(cfg.fit_points//2-1));last=min(len(power),k+cfg.fit_points//2+1)
  x=[n-k for n in range(first,last)];y=power[first:last]
  if len(x)<cfg.minimum_fit_points:failed=EDGE_LOCAL;continue
  intercept,a,mean_x,sxx=_line(x,y)
  if a==0 or (a>0)!=rising:failed=EDGE_FLAT;continue
  t=(threshold-intercept)/a
  # A fitted crossing outside the selected two-point bracket is ambiguous;
  # never silently clamp an extrapolation into a precise timestamp.
  if not -1e-10<=t<=1+1e-10:failed=EDGE_RINGING|EDGE_LOCAL;continue
  ef=k+t
  sigma=max(1.0,noise*noise+2*noise*max(threshold-noise,0))
  residual=sum((b-(intercept+a*c))**2 for c,b in zip(x,y))/(len(x)-2)
  v2=sigma*((1-frac)**2+frac**2)/(slope*slope)
  vf=max(sigma,residual)*(1/len(x)+(t-mean_x)**2/sxx)/(a*a)
  fused=(e2*vf+ef*v2)/(v2+vf)
  q=(EDGE_MULTI|EDGE_RINGING) if len(candidates)>1 else 0
  return Edge(fused,e2,ef,v2,vf,True,q,len(candidates))
 return Edge(quality=failed|((EDGE_MULTI|EDGE_RINGING) if len(candidates)>1 else 0),crossings=len(candidates))


def _spectral(z,first,last,coarse,cfg):
 if last-first+1<cfg.minimum_body:return 0.,0.,SPEC_TOO_SHORT,()
 # Frozen coarse bins are known before reading RAM. Exact pair centers are
 # accumulated, so stable-edge trimming does not assume equal populated bins.
 a,b=coarse;span=b-a
 e0=[0.]*cfg.segments;e1=[0.]*cfg.segments
 accum=[0j]*cfg.segments;times=[0.]*cfg.segments;counts=[0]*cfg.segments
 for n in range(first+1,last+1):
  center=n-.5
  segment=max(0,min(cfg.segments-1,int((center-a)*cfg.segments/span)))
  e0[segment]+=abs(z[n])**2;e1[segment]+=abs(z[n-1])**2
  accum[segment]+=z[n]*z[n-1].conjugate();times[segment]+=center;counts[segment]+=1
 x=[];phase=[]
 for total,t,count,ea,eb in zip(accum,times,counts,e0,e1):
  if count:
   if abs(total)<1e-20:return 0.,0.,SPEC_ZERO,()
   if 4*abs(total)**2<ea*eb:return 0.,0.,SPEC_COHERENCE,()
   x.append(t/count);phase.append(cmath.phase(total)/(2*math.pi))
 if len(x)<2:return 0.,0.,SPEC_SEGMENTS,tuple(x)
 # No unannounced Nyquist/chirp unwrap: a jump beyond the declared segment
 # range is ambiguous, even if a host polynomial could invent an alias order.
 if any(abs(v)>cfg.maximum_frequency_fraction for v in phase) or any(abs(phase[i]-phase[i-1])>cfg.maximum_segment_delta_turn for i in range(1,len(phase))):
  return 0.,0.,SPEC_AMBIGUOUS,tuple(x)
 intercept,slope,_,_=_line(x,phase)
 return intercept*cfg.sample_rate,slope*cfg.sample_rate**2,0,tuple(x)


def _polarization(z,noise,top,coarse,good,known,cfg):
 p=[v.real*v.real+v.imag*v.imag for v in z]
 threshold=noise+top/2
 rise=_edge(p,threshold,noise,coarse[0],True,cfg)
 fall=_edge(p,threshold,noise,coarse[1],False,cfg)
 result=Polarization(rise=rise,fall=fall,threshold_power=threshold)
 result.edge_quality=rise.quality|fall.quality
 if not good:result.edge_quality|=EDGE_BAD_SOURCE
 if not known or top<=0 or (noise>0 and top/noise<cfg.minimum_snr):result.edge_quality|=EDGE_LOW_SNR
 result.timing_valid=rise.valid and fall.valid and rise.index<fall.index and not (result.edge_quality&(EDGE_LOW_SNR|EDGE_BAD_SOURCE))
 if not result.timing_valid:result.spectral_quality=SPEC_BAD_EDGES;return result
 result.body_first=math.ceil(rise.index-1e-10)+cfg.body_guard
 result.body_last=math.floor(fall.index+1e-10)-cfg.body_guard
 if result.body_first<=result.body_last:
  body=p[result.body_first:result.body_last+1]
  result.mean_body_power=sum(body)/len(body)
  result.snr=max(result.mean_body_power-noise,0)/noise if noise else math.inf
 f,k,q,centers=_spectral(z,result.body_first,result.body_last,coarse,cfg)
 result.frequency_hz=f;result.chirp_hz_per_s=k;result.spectral_quality=q;result.segment_centers=centers;result.spectral_valid=q==0
 return result


def measure(h,v,*,noise,top_signal,coarse,source_good=(True,True),noise_known=(True,True),config=None):
 cfg=config or FineConfig()
 if not (len(h)==len(v) and 1<=len(h)<=16384 and 0<=coarse[0]<coarse[1]<=len(h)):
  raise ValueError('RAW/coarse geometry')
 if not (cfg.fit_points==8 and 4<=cfg.minimum_fit_points<=8 and 1<=cfg.body_guard<=16 and cfg.segments in (8,16) and cfg.sample_rate==125_000_000):
  raise ValueError('unsupported Fine configuration')
 if len(noise)!=2 or len(top_signal)!=2 or any(not math.isfinite(x) or x<0 for x in (*noise,*top_signal)):
  raise ValueError('invalid frozen power prior')
 if any(not math.isfinite(z.real) or not math.isfinite(z.imag) for z in (*h,*v)):
  raise ValueError('nonfinite IQ')
 hp=_polarization(h,noise[0],top_signal[0],coarse,source_good[0],noise_known[0],cfg)
 vp=_polarization(v,noise[1],top_signal[1],coarse,source_good[1],noise_known[1],cfg)
 result=Result(hp,vp)
 if hp.timing_valid and vp.timing_valid:
  result.hv_first=max(hp.body_first,vp.body_first);result.hv_last=min(hp.body_last,vp.body_last)
  if result.hv_last-result.hv_first+1>=cfg.minimum_body:
   cross=sum(h[n]*v[n].conjugate() for n in range(result.hv_first,result.hv_last+1))
   eh=sum(abs(h[n])**2 for n in range(result.hv_first,result.hv_last+1));ev=sum(abs(v[n])**2 for n in range(result.hv_first,result.hv_last+1))
   if abs(cross)>1e-20 and 4*abs(cross)**2>=eh*ev:
    result.hv_valid=True;result.hv_phase_turn=(cmath.phase(cross)/(2*math.pi)+.5)%1-.5
 return result


def offline_phase_fit(z,first,last,sample_rate=125_000_000):
 """Independent host oracle: unwrap each sample angle, fit quadratic phase.

 This intentionally uses no adjacent-product segment sums and is not a PL model.
 """
 if last-first+1<3:raise ValueError('insufficient phase samples')
 values=[];previous=0
 for n in range(first,last+1):
  angle=cmath.phase(z[n])
  if values:angle=previous+(angle-previous+math.pi)%(2*math.pi)-math.pi
  values.append(angle);previous=angle
 center=(first+last)/2;x=[n-center for n in range(first,last+1)]
 # Solve the centered quadratic normal equations by pivoted elimination.
 matrix=[[sum(t**(i+j) for t in x) for j in range(3)]+[sum((t**i)*a for t,a in zip(x,values))] for i in range(3)]
 for col in range(3):
  pivot=max(range(col,3),key=lambda row:abs(matrix[row][col]));matrix[col],matrix[pivot]=matrix[pivot],matrix[col]
  divisor=matrix[col][col]
  if divisor==0:raise ValueError('singular phase fit')
  matrix[col]=[v/divisor for v in matrix[col]]
  for row in range(3):
   if row!=col:
    factor=matrix[row][col];matrix[row]=[a-factor*b for a,b in zip(matrix[row],matrix[col])]
 c=[row[3] for row in matrix]
 return (c[1]-2*c[2]*center)*sample_rate/(2*math.pi),2*c[2]*sample_rate**2/(2*math.pi)
