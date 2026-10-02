"""Freeze the input manifests before running the Fine delivery checks.
Generate/configure the capture RAM IP first. Do not run this midway through a
validation to conceal input changes: the collector rejects mismatched hashes.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json
ROOT=Path(__file__).resolve().parents[1]

def save(name, files):
    data=dict(utc=datetime.now(timezone.utc).isoformat(),sha256={
        p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(set(files))})
    (ROOT/'reports'/name).write_text(json.dumps(data,indent=2)+'\n')

synth=list((ROOT/'rtl').rglob('*.sv'))+[ROOT/'hw/tcl/instrument_v06_fine.tcl']
for path in ['build/ip_probe_2025_2/calibrator_ip_probe.srcs/sources_1/ip/capture_ram_probe/capture_ram_probe.xci',
             'build/ip_probe_2025_2/calibrator_ip_probe.gen/sources_1/ip/capture_ram_probe/capture_ram_probe.dcp']:
    source=ROOT/path
    assert source.is_file(), 'Generate capture RAM IP before snapshot: '+path
    synth.append(source)
files=[]
for folder, extensions in [('rtl',['*.sv']),('tb',['*.sv']),('tests',['*.py','*.c']),
                            ('sw/common',['*.c','*.h']),('contracts',['*.json'])]:
    for extension in extensions:files.extend((ROOT/folder).rglob(extension))
save('v06_fine_final_inputs.json',synth)
save('v06_fine_final_validation_inputs.json',files)
print('Frozen Fine synthesis and validation input hashes; run checks without changing these inputs.')
