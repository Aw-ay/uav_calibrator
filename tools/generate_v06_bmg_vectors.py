"""Independent RAW ABI oracle for the actual-BMG B128 chain XSim test."""
from pathlib import Path
import random,struct
from frame_codec import encode_frame
ROOT=Path(__file__).resolve().parents[1]
def main():
 out=ROOT/'reports/v06_bmg_stream_vectors';out.mkdir(exist_ok=True)
 rng=random.Random(606)
 mem=[tuple(rng.randrange(-32768,32768) for _ in range(4)) for _ in range(16384)]
 frame=encode_frame({'format_id':7,'pulse_id':0xfedcba9876543210},
  [mem[(16383+i)%16384] for i in range(16384)],trailer=True,header_crc=True)
 (out/'ram.hex').write_text('\n'.join((struct.pack('<hhhh',*mem[i])+struct.pack('<hhhh',*mem[i+1]))[::-1].hex() for i in range(0,16384,2)))
 (out/'header.hex').write_text(frame[:128][::-1].hex())
 (out/'expected.hex').write_text('\n'.join(f'{b:02x}' for b in frame))
 print(f'Generated independent actual-BMG oracle: {len(frame)} bytes')
if __name__=='__main__':main()
