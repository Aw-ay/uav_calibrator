from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    exe=str(Path(tmp)/'test.exe')
    subprocess.run(['C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe','-std=c11','-Wall','-Wextra','-Werror','-pedantic',
        '-Isw/common/include','tests/c/test_digital_capture_control.c','sw/common/capture_budget.c','sw/common/command_control.c','sw/common/digital_capture_control.c','-o',exe],cwd=ROOT,check=True)
    subprocess.run([exe],check=True)
