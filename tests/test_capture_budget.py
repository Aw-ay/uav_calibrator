from pathlib import Path
import subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    exe=Path(tmp)/'budget.exe'
    subprocess.run(['C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe',
        '-std=c11','-Wall','-Wextra','-Werror','-pedantic','-I',str(ROOT/'sw/common/include'),
        str(ROOT/'tests/c/test_capture_budget.c'),str(ROOT/'sw/common/capture_budget.c'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
