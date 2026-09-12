"""Build the portable receive and command library with the installed 2025.2 A53 tools.

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

sources = [ROOT/'sw/common/frame_decode.c', ROOT/'sw/common/dma_slots.c', ROOT/'sw/common/event_control.c', ROOT/'sw/common/calibration_table.c', ROOT/'sw/common/command_control.c', ROOT/'sw/common/waveform_control.c', ROOT/'sw/common/pdw_control.c']
status = 'FAIL'
try:
    run([BIN/'aarch64-none-elf-gcc.exe', '--version'])
    objects = []
    for source in sources:
        obj = OUT / (source.stem + '.o')
        run([BIN/'aarch64-none-elf-gcc.exe', '-mcpu=cortex-a53', '-std=c11',
             '-ffreestanding', '-O2', '-Wall', '-Wextra', '-Werror', '-pedantic',
             '-I', ROOT/'sw/common', '-I', ROOT/'sw/common/include', '-c', source, '-o', obj])
        description = run([BIN/'aarch64-none-elf-objdump.exe', '-f', obj])
        if 'architecture: aarch64' not in description:
            raise RuntimeError('Unexpected object architecture: ' + description)
        objects.append(obj)
    library = OUT/'libcalibrator_receive.a'
    run([BIN/'aarch64-none-elf-ar.exe', 'rcs', library, *objects])
    symbols = run([BIN/'aarch64-none-elf-nm.exe', '-g', '--defined-only', library])
    for symbol in ['cal_command_begin','cal_command_poll','cal_dds_begin','cal_awg_load_begin','cal_awg_write','cal_awg_commit','cal_awg_play','cal_awg_crc32c','cal_pdw_peek_begin','cal_pdw_pop_begin','cal_pdw_snapshot_decode']:
        if not any(line.split()[-2:] == ['T', symbol] for line in symbols.splitlines()):
            raise RuntimeError('Missing A53 archive API: ' + symbol)
    status = 'PASS'
finally:
    report = dict(status=status, scope='A53 portable static library only; no BSP/ELF/hardware test',
                  tools_release='2025.2', records=records,
                  hashes={p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sources + sorted((ROOT/'sw/common').rglob('*.h')) + sorted(OUT.glob('*.o')) + sorted(OUT.glob('*.a'))})
    (ROOT/'reports/ps_common_a53_build.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('PASS: Cortex-A53 objects and static library built; no executable or hardware claim.')
