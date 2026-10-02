from pathlib import Path
import subprocess,tempfile,os,sys,struct,importlib.util
ROOT=Path(__file__).resolve().parents[1]
gcc=Path('C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe')
def run(args):
 p=subprocess.run([str(a) for a in args],cwd=ROOT,capture_output=True,text=True,timeout=60,env={**os.environ,'PATH':str(gcc.parent)+os.pathsep+os.environ['PATH']});assert p.returncode==0,p.stdout+p.stderr;return p.stdout
with tempfile.TemporaryDirectory() as tmp:
 print(run([sys.executable,'tests/test_aux_record_metadata.py']))
 lines=(ROOT/'reports/aux_metadata_vector.txt').read_text().splitlines();raw=bytes.fromhex(lines[0])[::-1]
 expected=struct.pack('<IHHIIQQQQQQIIIIIIBBBB I',0x41555831,1,96,0xfedcba98,9,0x123456789abcdef0,0xabcdef0123456789,0x9876543210abcdef,0xfedcba9876543210,1234,5678,7,11,12,13,14,16384,3,2,0,0,0)
 assert raw==expected,'independent byte layout'
 header=bytes.fromhex(lines[1])[::-1];gold=bytearray(128)
 for offset,fmt,value in [(0,'I',0x43414c31),(4,'H',5),(6,'H',128),(8,'I',131216),(12,'I',131072),(16,'Q',0x123456789abcdef0),(32,'I',9),(36,'I',13),(40,'Q',5678),(52,'I',4),(56,'I',125000000),(60,'I',1),(64,'I',16384),(68,'I',4),(72,'B',2),(73,'B',3),(74,'H',7),(88,'I',14),(92,'I',0xfedcba98),(116,'B',4),(117,'B',0x88),(118,'B',3),(119,'B',8),(120,'I',7)]:struct.pack_into('<'+fmt,gold,offset,value)
 assert header==gold,'independent full 128-byte RAW header'
 vec=Path(tmp)/'vector.bin';vec.write_bytes(raw);exe=Path(tmp)/'test.exe'
 run([gcc,'-std=c11','-Wall','-Wextra','-Werror','-pedantic','-I','sw/common/include','sw/common/aux_metadata_decode.c','tests/c/test_aux_metadata_decode.c','-o',exe]);print(run([exe,vec]))
 spec=importlib.util.spec_from_file_location('gen',ROOT/'tools/generate_aux_metadata.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.generate(tmp)
 for p in Path(tmp).rglob('*'):
  if p.is_file() and p.suffix in ('.sv','.h','.md','.m'):assert p.read_bytes().replace(b'\r\n',b'\n')==(ROOT/p.relative_to(tmp)).read_bytes().replace(b'\r\n',b'\n'),p
 print('PASS generated AUX ABI reproducibility')
