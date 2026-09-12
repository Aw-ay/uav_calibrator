from pathlib import Path
import subprocess,tempfile,os,json
ROOT=Path(__file__).resolve().parents[1]
gcc=Path('C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe')
a53=Path('C:/AMDDesignTools/2025.2/gnu/aarch64/nt/aarch64-none/bin/aarch64-none-elf-gcc.exe')
def run(args):
 p=subprocess.run([str(a) for a in args],cwd=ROOT,capture_output=True,text=True,env={**os.environ,'PATH':str(gcc.parent)+os.pathsep+os.environ['PATH']})
 assert p.returncode==0,p.stdout+p.stderr
 return p.stdout
flags=['-std=c11','-Wall','-Wextra','-Werror','-pedantic','-I','sw/common/include']
with tempfile.TemporaryDirectory() as tmp:
 exe=Path(tmp)/'test.exe'
 run([gcc,*flags,'sw/common/command_control.c','sw/common/source_event_control.c','tests/c/test_source_event_control.c','-o',exe]);print(run([exe]))
 out=ROOT/'build/ps_control_extensions_a53/source_event_control.o';out.parent.mkdir(parents=True,exist_ok=True)
 run([a53,*flags,'-mcpu=cortex-a53','-ffreestanding','-c','sw/common/source_event_control.c','-o',out])
 print('PASS A53 source event freestanding compile')
