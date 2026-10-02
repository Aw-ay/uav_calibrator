from pathlib import Path
import subprocess,tempfile,os
r=Path(__file__).resolve().parents[1];gcc=Path('C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe')
with tempfile.TemporaryDirectory() as tmp:
 exe=Path(tmp)/'test.exe'
 for args in [[str(gcc),'-std=c11','-Wall','-Wextra','-Werror','-Itests/mocks/sg_dma','-Isw/baremetal','sw/baremetal/sg_counter_rx.c','sw/common/dma_slots.c','tests/c/test_sg_counter_rx.c','-o',str(exe)],[str(exe)]]:
  p=subprocess.run(args,cwd=r,capture_output=True,text=True,timeout=30,env={**os.environ,'PATH':str(gcc.parent)+os.pathsep+os.environ['PATH']});assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout)
