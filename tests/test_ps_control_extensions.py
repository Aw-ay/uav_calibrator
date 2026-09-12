from pathlib import Path
import subprocess,tempfile,runpy,json,hashlib,os
ROOT=Path(__file__).resolve().parents[1]
assert (ROOT/'sw/common/include/calibration_table_format.h').read_text()==runpy.run_path(str(ROOT/'tools/generate_calibration_table_format.py'))['render']()
GCC=Path('C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe')
A53=Path('C:/AMDDesignTools/2025.2/gnu/aarch64/nt/aarch64-none/bin/aarch64-none-elf-gcc.exe')
sources=[ROOT/'sw/common/event_control.c',ROOT/'sw/common/calibration_table.c',ROOT/'sw/common/frame_decode.c']
records=[]
def run(args):
    p=subprocess.run([str(a) for a in args],capture_output=True,text=True,timeout=60,env={**os.environ,'PATH':str(GCC.parent)+os.pathsep+os.environ.get('PATH','')})
    records.append({'command':[str(a) for a in args],'exit_code':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
    assert p.returncode==0,p.stdout+p.stderr
    return p.stdout
with tempfile.TemporaryDirectory() as tmp:
    exe=Path(tmp)/'test.exe'
    run([GCC,'-std=c11','-O2','-Wall','-Wextra','-Werror','-pedantic','-I',ROOT/'sw/common',*sources,ROOT/'tests/c/test_ps_control_extensions.c','-o',exe])
    print(run([exe]))
out=ROOT/'build/ps_control_extensions_a53';out.mkdir(parents=True,exist_ok=True)
run([A53,'--version'])
for source in sources[:2]:
    obj=out/(source.stem+'.o')
    run([A53,'-mcpu=cortex-a53','-std=c11','-ffreestanding','-O2','-Wall','-Wextra','-Werror','-pedantic','-I',ROOT/'sw/common','-c',source,'-o',obj])
    text=run([A53.parent/'aarch64-none-elf-objdump.exe','-f',obj]);assert 'architecture: aarch64' in text
(ROOT/'reports/ps_control_extensions.json').write_text(json.dumps({'status':'PASS','scope':'Host execution plus A53 freestanding objects only; no BSP/ELF/hardware claim','records':records,'sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [*sources[:2],*out.glob('*.o')]}},indent=2))
print('PASS A53 control extension objects')
