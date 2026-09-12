"""ABI5 byte codec. format_id is explicit because its numeric enum is not frozen."""
import pathlib,struct
from generate_contracts import load_contracts,validate
_contracts=load_contracts(pathlib.Path(__file__).resolve().parents[1]/'contracts')
validate(_contracts)
F=_contracts['frame_format']; S=_contracts['system_contract']; HEADER=F['header_bytes']
FMT={'u8':'B','u16':'H','u32':'I','u64':'Q','i32':'i','i64':'q'}
FIELDS={x['name']:x for x in F['header']}; MAGIC=int(FIELDS['magic']['meaning'],16)
DISABLED=1<<next(int(k) for k,v in F['quality_flag_bits'].items() if v=='CRC_DISABLED')
TRAILER=1<<next(int(k) for k,v in F['quality_flag_bits'].items() if v=='HAS_CRC_TRAILER')
def crc32c(data):
 crc=0xffffffff
 for byte in data:
  crc^=byte
  for _ in range(8):crc=(crc>>1)^(0x82f63b78 if crc&1 else 0)
 return crc^0xffffffff
def pack_header(values):
 b=bytearray(HEADER)
 try:
  for name,x in FIELDS.items():
   if x['type']=='bytes':
    v=values.get(name,bytes(x['size_bytes']))
    if v!=bytes(x['size_bytes']):raise ValueError('reserved header must be zero')
   else:struct.pack_into('<'+FMT[x['type']],b,x['offset_bytes'],values.get(name,0))
 except (struct.error,TypeError) as exc:raise ValueError('header value outside ABI type') from exc
 return b
def encode_frame(metadata,samples,*,trailer=False,header_crc=True):
 samples=list(samples);n=len(samples)
 if not 1<=n<=F['payload']['max_samples']:raise ValueError('sample count outside ABI')
 if 'format_id' not in metadata:raise ValueError('format_id numeric assignment required')
 if set(metadata)-set(FIELDS):raise ValueError('unknown header field')
 try:payload=b''.join(struct.pack('<hhhh',*sample) for sample in samples)
 except (struct.error,TypeError) as exc:raise ValueError('expected four signed IQ16 values per sample') from exc
 h=dict(metadata);flags=h.get('quality_flags',0)&~(DISABLED|TRAILER)
 flags|=(0 if header_crc else DISABLED)|(TRAILER if trailer else 0)
 h.update(magic=MAGIC,schema_version=F['abi_version'],header_bytes=HEADER,record_bytes=HEADER+len(payload)+(F['trailer']['bytes'] if trailer else 0),payload_bytes=len(payload),sample_count=n,quality_flags=flags,header_crc32c=0)
 h.setdefault('sample_stride_ticks',S['rates']['pl_decimation']);h.setdefault('sample_rate_num',S['rates']['core_complex_hz']);h.setdefault('sample_rate_den',1)
 b=pack_header(h)
 if header_crc:
  h['header_crc32c']=crc32c(b);b=pack_header(h)
 tail=struct.pack('<IIII',int(F['trailer']['magic_hex'],16),crc32c(payload),len(payload),0) if trailer else b''
 result=bytes(b)+payload+tail
 decode_frame(result)
 return result
def decode_frame(data):
 data=bytes(data)
 if len(data)<HEADER:raise ValueError('short header')
 h={n:(data[x['offset_bytes']:x['offset_bytes']+x['size_bytes']] if x['type']=='bytes' else struct.unpack_from('<'+FMT[x['type']],data,x['offset_bytes'])[0]) for n,x in FIELDS.items()}
 if h['magic']!=MAGIC or h['schema_version']!=F['abi_version'] or h['header_bytes']!=HEADER:raise ValueError('header magic/version/length')
 if h['reserved']!=bytes(FIELDS['reserved']['size_bytes']):raise ValueError('nonzero header reserved')
 n=h['sample_count'];p=h['payload_bytes'];has_trailer=bool(h['quality_flags']&TRAILER)
 if not 1<=n<=F['payload']['max_samples'] or p!=8*n:raise ValueError('payload sample length')
 expected=HEADER+p+(F['trailer']['bytes'] if has_trailer else 0)
 if h['record_bytes']!=expected or len(data)!=expected:raise ValueError('record length')
 if not h['sample_rate_num'] or not h['sample_rate_den'] or not h['sample_stride_ticks']:raise ValueError('invalid sample grid')
 if not h['quality_flags']&DISABLED:
  clean=bytearray(data[:HEADER]);o=FIELDS['header_crc32c']['offset_bytes'];clean[o:o+4]=bytes(4)
  if crc32c(clean)!=h['header_crc32c']:raise ValueError('header CRC32C')
 payload=data[HEADER:HEADER+p]
 if has_trailer:
  magic,crc,length,reserved=struct.unpack_from('<IIII',data,HEADER+p)
  if magic!=int(F['trailer']['magic_hex'],16) or length!=p or reserved or crc!=crc32c(payload):raise ValueError('trailer/CRC32C')
 return h,list(struct.iter_unpack('<hhhh',payload))
