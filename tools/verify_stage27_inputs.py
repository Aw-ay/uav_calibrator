"""Check generated interfaces and archive current source hashes, no hardware claim."""
from pathlib import Path
import hashlib,json,sys,tempfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import generate_contracts as contracts
import generate_replay_control_layout as replay
import generate_task_doppler as doppler
assert (ROOT/'rtl/replay/replay_control_layout_pkg.sv').read_text()==replay.render()
assert (ROOT/'rtl/replay/task_doppler_phase.sv').read_text()==doppler.render()
task=json.loads((ROOT/'contracts/replay_contract.json').read_text())['replay_task']
spans=[]
c=(ROOT/'sw/common/include/replay_task_layout.h').read_text()
m=(ROOT/'sw/matlab/replay_task_layout.m').read_text()
for f in task['fields']:
    a=f['offset_bytes'];b=a+f['size_bytes'];assert 0<=a<b<=task['size_bytes'];spans.append((a,b))
    assert f"#define CAL_REPLAY_{f['name'].upper()}_OFFSET {a}u" in c
    assert f"x.{f['name']} = {a};" in m
for left,right in zip(sorted(spans),sorted(spans)[1:]):assert left[1]<=right[0]
with tempfile.TemporaryDirectory() as d:
    tmp=Path(d);manifest=contracts.generate(contracts.load_contracts(ROOT/'contracts'),tmp)
    for rel in manifest['outputs_sha256']:
        assert (ROOT/rel).read_text()==(tmp/rel).read_text(),rel
    (ROOT/'reports/contract_abi_manifest.json').write_text((tmp/'reports/contract_abi_manifest.json').read_text())
paths=[]
for folder in ['rtl','contracts','sw/common','tb','tests','hw/tcl']:
    paths += [p for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in ['.sv','.json','.c','.h','.py','.tcl']]
paths += list((ROOT/'tools').glob('*.py'))
out=ROOT/'reports/module_stage27';out.mkdir(parents=True,exist_ok=True)
hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))}
(out/'inputs.json').write_text(json.dumps({'scope':'stage27 source snapshot; complex_cal_core contains pre-existing external modifications, preserved and included in verification inputs','sha256':hashes},indent=2)+'\n')
print(f'PASS generated SV/C/MATLAB task offsets, Doppler ROM and bounded ABI export consistency; {len(hashes)} source hashes')
