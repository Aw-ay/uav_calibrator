"""Build the portable receive library with the installed 2025.2 A53 tools.

No BSP, startup code, linker script or board executable is fabricated here.
"""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BIN = Path('C:/AMDDesignTools/2025.2/gnu/aarch64/nt/aarch64-none/bin')
OUT = ROOT / 'build/ps_common_a53_2025_2'
OUT.mkdir(parents=True, exist_ok=True)
records = []

def run(args):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True, text=True)
    records.append(dict(command=[str(a) for a in args], exit_code=result.returncode,
                        stdout=result.stdout, stderr=result.stderr))
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

sources = [ROOT/'sw/common/frame_decode.c', ROOT/'sw/common/dma_slots.c', ROOT/'sw/common/event_control.c', ROOT/'sw/common/calibration_table.c']
status = 'FAIL'
try:
    run([BIN/'aarch64-none-elf-gcc.exe', '--version'])
    objects = []
    for source in sources:
        obj = OUT / (source.stem + '.o')
        run([BIN/'aarch64-none-elf-gcc.exe', '-mcpu=cortex-a53', '-std=c11',
             '-ffreestanding', '-O2', '-Wall', '-Wextra', '-Werror', '-pedantic',
             '-I', ROOT/'sw/common', '-c', source, '-o', obj])
        description = run([BIN/'aarch64-none-elf-objdump.exe', '-f', obj])
        if 'architecture: aarch64' not in description:
            raise RuntimeError('Unexpected object architecture: ' + description)
        objects.append(obj)
    library = OUT/'libcalibrator_receive.a'
    run([BIN/'aarch64-none-elf-ar.exe', 'rcs', library, *objects])
    status = 'PASS'
finally:
    report = dict(status=status, scope='A53 portable static library only; no BSP/ELF/hardware test',
                  tools_release='2025.2', records=records,
                  hashes={p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sources + sorted(OUT.glob('*.o')) + sorted(OUT.glob('*.a'))})
    (ROOT/'reports/ps_common_a53_build.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('PASS: Cortex-A53 objects and static library built; no executable or hardware claim.')
