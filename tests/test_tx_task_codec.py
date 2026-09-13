from pathlib import Path
import subprocess,tempfile,os,sys
ROOT=Path(__file__).resolve().parents[1]
gcc=Path('C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe')
def run(args):
 p=subprocess.run([str(a) for a in args],cwd=ROOT,capture_output=True,text=True,timeout=30,env={**os.environ,'PATH':str(gcc.parent)+os.pathsep+os.environ['PATH']});assert p.returncode==0,p.stdout+p.stderr;return p.stdout
with tempfile.TemporaryDirectory() as tmp:
 exe=Path(tmp)/'test.exe'
 run([gcc,'-std=c11','-Wall','-Wextra','-Werror','-pedantic','-I','sw/common/include','sw/common/event_control.c','sw/common/fault_event_decode.c','sw/common/tx_lifecycle_decode.c','sw/common/replay_identity_decode.c','sw/common/unified_event_reader.c','tests/c/test_tx_task_decode.c','-o',exe])
 print(run([sys.executable,'tests/test_tx_task_lifecycle.py']))
 print(run([exe,ROOT/'reports/module_stage20/rtl_records.txt']))
