"""Finite-width numerical kernels for Fine; not the complete streaming engine."""
ATAN_Q31=(268435456, 158466703, 83729454, 42502378, 21333666, 10677233, 5339919, 2670123, 1335082, 667543, 333772, 166886, 83443, 41722, 20861, 10430, 5215, 2608, 1304, 652, 326, 163, 81, 41, 20, 10, 5, 3, 1, 1, 0)

def signed(value,width):
 if not -(1<<(width-1))<=value<(1<<(width-1)):raise OverflowError((value,width))
 return value

def cordic_phase_q31(x,y):
 """Signed48 input, signed48 vector registers, arithmetic shifts, 31 rotations.

 Return signed turns*2^31 in [-2^30,2^30). Zero vector is invalid.
 """
 signed(x,48);signed(y,48)
 if x==0 and y==0:raise ValueError('zero vector has no phase')
 high=max(abs(x),abs(y)).bit_length()-1
 shift=44-high
 phase=0
 if x<0:
  phase=(1<<30) if y>=0 else -(1<<30);x,y=-x,-y
 if shift>=0:x,y=x<<shift,y<<shift
 else:x,y=x>>(-shift),y>>(-shift)
 signed(x,48);signed(y,48)
 for i,angle in enumerate(ATAN_Q31):
  if y>0:x,y,phase=x+(y>>i),y-(x>>i),phase+angle
  elif y<0:x,y,phase=x-(y>>i),y+(x>>i),phase-angle
  signed(x,48);signed(y,48);signed(phase,33)
 return (phase+(1<<30))%(1<<31)-(1<<30)


from dataclasses import dataclass
from fractions import Fraction

@dataclass(frozen=True)
class FixedEdge:
 index_q16:int=0
 two_q16:int=0
 fit_q16:int=0
 variance_two_q32:int=0
 variance_fit_q32:int=0
 valid:bool=False
 quality:int=0


def rounded_divide(n,d):
 """Nearest integer, exact halves away from zero; no float conversion."""
 if d==0:raise ZeroDivisionError
 negative=(n<0)!=(d<0);q,r=divmod(abs(n),abs(d))
 if 2*r>=abs(d):q+=1
 return -q if negative else q


def _fraction(n,d):
 signed(n,256);signed(d,256)
 return Fraction(n,d)


def edge_pair_q16(power,k,threshold,noise,rising):
 """Numerical kernel for one selected bracket. Not a streaming edge search.

 Powers/noise/threshold are unsigned32 but physical IQ power is at most2^31.
 Exact rational variance uses bounded signed256 reference arithmetic; emitted
 variances are unsigned64 Q32. Overflow invalidates rather than wraps/saturates.
 A future RTL implementation must preserve this operation/rounding contract.
 """
 if not 0<=k<len(power)-1 or len(power)>16384:raise ValueError('edge bracket')
 if any(not isinstance(p,int) or not 0<=p<=1<<31 for p in power):raise ValueError('IQ power range')
 if not 0<=threshold<=0xffffffff or not 0<=noise<=1<<31:raise ValueError('prior range')
 p0,p1=power[k:k+2]
 if not (p0<threshold<=p1 if rising else p0>=threshold>p1):return FixedEdge(quality=2 if rising else 4)
 first=max(0,k-3);last=min(len(power),k+5);m=last-first
 if m<4:return FixedEdge(quality=64)
 xs=list(range(first-k,last-k));ps=power[first:last]
 sx=sum(xs);sxx=sum(x*x for x in xs);sy=sum(ps);sxy=sum(x*p for x,p in zip(xs,ps))
 denominator=m*sxx-sx*sx
 slope=m*sxy-sx*sy;intercept=sy*sxx-sx*sxy
 numerator=threshold*denominator-intercept
 signed(slope,48);signed(intercept,48);signed(numerator,48)
 if slope==0 or (slope>0)!=rising:return FixedEdge(quality=8)
 t=_fraction(numerator,slope)
 if not 0<=t<=1:return FixedEdge(quality=32|64)
 delta=p1-p0;offset=threshold-p0
 two=(k<<16)+rounded_divide(offset<<16,delta)
 fit=(k<<16)+rounded_divide(numerator<<16,slope)
 sigma=max(1,noise*noise+2*noise*max(threshold-noise,0))
 residual=sum((denominator*p-intercept-slope*x)**2 for x,p in zip(xs,ps))
 fit_sigma=max(Fraction(sigma),_fraction(residual,denominator**2*(m-2)))
 v2=_fraction(sigma*((delta-offset)**2+offset**2),delta**4)
 vf=fit_sigma*_fraction(denominator*(denominator*slope*slope+(m*numerator-slope*sx)**2),m*slope**4)
 for v in [v2,vf]:signed(v.numerator,256);signed(v.denominator,256)
 v2q=max(1,rounded_divide(v2.numerator<<32,v2.denominator))
 vfq=max(1,rounded_divide(vf.numerator<<32,vf.denominator))
 if max(v2q,vfq)>0xffffffffffffffff:return FixedEdge(quality=256)
 combined=two*vfq+fit*v2q;signed(combined,128)
 index=rounded_divide(combined,v2q+vfq)
 return FixedEdge(index,two,fit,v2q,vfq,True,0)


def _iq_samples(samples):
 for i,q in samples:signed(i,16);signed(q,16)
 if not 1<=len(samples)<=16384:raise ValueError('RAW size')

def _product(a,b):
 i,q=a;j,r=b
 return signed(i*j+q*r,33),signed(q*j-i*r,33)

def spectral_fixed(samples,first,last,coarse):
 """Integer segment accumulator + shared Q31 CORDIC + integer LS finalize.

 No per-sample phase extraction; eight coarse-coordinate bins. All numerator
 arithmetic is checked signed256, emitted frequency i32 and chirp i64.
 """
 _iq_samples(samples)
 if not 0<=first<=last<len(samples):return dict(valid=False,quality=1)
 if last-first+1<9:return dict(valid=False,quality=1)
 a,b=coarse
 if not 0<=a<b<=len(samples):raise ValueError('coarse geometry')
 bins=[[0,0,0,0,0,0] for _ in range(8)]
 for n in range(first+1,last+1):
  segment=max(0,min(7,((2*n-1-2*a)*8)//(2*(b-a))))
  re,im=_product(samples[n],samples[n-1]);row=bins[segment]
  row[0]=signed(row[0]+re,48);row[1]=signed(row[1]+im,48);row[2]+=2*n-1;row[3]+=1
  row[4]+=sum(v*v for v in samples[n]);row[5]+=sum(v*v for v in samples[n-1])
 x=[];y=[]
 for re,im,twice_center,count,e0,e1 in bins:
  if count:
   if re==0 and im==0:return dict(valid=False,quality=4)
   if 4*(re*re+im*im)<e0*e1:return dict(valid=False,quality=32)
   x.append(rounded_divide(twice_center<<15,count));y.append(cordic_phase_q31(re,im))
 if len(x)<2:return dict(valid=False,quality=2)
 if any(abs(v)*100>49*(1<<31) for v in y) or any(abs(y[n]-y[n-1])>(1<<29) for n in range(1,len(y))):return dict(valid=False,quality=8)
 count=len(x);sx=sum(x);sy=sum(y);sxx=sum(v*v for v in x);sxy=sum(a*b for a,b in zip(x,y))
 denominator=count*sxx-sx*sx
 if denominator<=0:return dict(valid=False,quality=2)
 intercept=sy*sxx-sx*sxy;slope=count*sxy-sx*sy
 fn=signed(intercept*125000000,256);fd=signed(denominator*(1<<31),256)
 kn=signed(slope*125000000**2,256);kd=signed(denominator*(1<<15),256)
 frequency=signed(rounded_divide(fn,fd),32);chirp=signed(rounded_divide(kn,kd),64)
 return dict(valid=True,quality=0,frequency_hz=frequency,chirp_hz_per_s=chirp,centers_q16=tuple(x),phase_q31=tuple(y))


def hv_phase_fixed(h,v,first,last):
 _iq_samples(h);_iq_samples(v)
 if len(h)!=len(v):raise ValueError('HV length')
 if not 0<=first<=last<len(h) or last-first+1<9:return dict(valid=False,quality=1)
 real=imag=eh=ev=0
 for n in range(first,last+1):
  re,im=_product(h[n],v[n]);real=signed(real+re,48);imag=signed(imag+im,48)
  eh+=sum(a*a for a in h[n]);ev+=sum(a*a for a in v[n])
 if real==0 and imag==0:return dict(valid=False,quality=4)
 if 4*(real*real+imag*imag)<eh*ev:return dict(valid=False,quality=32)
 return dict(valid=True,quality=0,phase_q31=cordic_phase_q31(real,imag))


def measure_fixed(h,v,*,noise,top_signal,coarse,source_good=(True,True),noise_known=(True,True)):
 """Batch composition of the integer kernels; NOT a one-pass/cycle proof.

 All emitted numeric fields are integers. Local edge variances use the bounded
 rational kernel above, with explicit Q16/Q32 rounding at kernel boundaries.
 """
 _iq_samples(h);_iq_samples(v)
 if len(h)!=len(v) or not 0<=coarse[0]<coarse[1]<=len(h):raise ValueError('Fine geometry')
 if len(noise)!=2 or len(top_signal)!=2 or any(not isinstance(x,int) or not 0<=x<=1<<31 for x in (*noise,*top_signal)):raise ValueError('frozen priors')
 outputs=[]
 for pol,samples in enumerate((h,v)):
  powers=[i*i+q*q for i,q in samples];threshold=noise[pol]+(top_signal[pol]>>1);edges=[];quality=0
  for which in (0,1):
   rising=which==0;center=coarse[which]
   indices=[k for k in range(max(0,center-8),min(len(samples)-2,center+8)+1) if (powers[k]<threshold<=powers[k+1] if rising else powers[k]>=threshold>powers[k+1])]
   edge=FixedEdge(quality=2 if rising else 4)
   for k in (indices if rising else indices[::-1]):
    edge=edge_pair_q16(powers,k,threshold,noise[pol],rising)
    if edge.valid:break
   quality|=edge.quality
   if len(indices)>1:quality|=16|32
   edges.append(edge)
  if not source_good[pol]:quality|=128
  if not noise_known[pol] or top_signal[pol]==0 or top_signal[pol]<4*noise[pol]:quality|=1
  valid=all(e.valid for e in edges) and edges[0].index_q16<edges[1].index_q16 and not quality&(1|128)
  out=dict(timing_valid=valid,edge_quality=quality,rise=edges[0],fall=edges[1],threshold_power=threshold,mean_body_power=0,snr_q16=0,snr_saturated=False,spectral=dict(valid=False,quality=16),body_first=0,body_last=-1)
  if valid:
   first=((edges[0].index_q16+65535)>>16)+4;last=(edges[1].index_q16>>16)-4
   out['body_first']=first;out['body_last']=last
   if first<=last:
    energy=sum(powers[first:last+1]);assert energy<(1<<46)
    mean=energy//(last-first+1);out['mean_body_power']=mean
    snr=((max(mean-noise[pol],0)<<16)//noise[pol]) if noise[pol] else 1<<32
    out['snr_q16']=min(snr,0xffffffff);out['snr_saturated']=snr>0xffffffff
   out['spectral']=spectral_fixed(samples,first,last,coarse)
  outputs.append(out)
 cross=dict(valid=False,quality=16)
 if all(p['timing_valid'] for p in outputs):
  cross=hv_phase_fixed(h,v,max(p['body_first'] for p in outputs),min(p['body_last'] for p in outputs))
 return dict(h=outputs[0],v=outputs[1],hv=cross)
