"""Verify released file hashes. Run before regeneration changes reports."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=ROOT/'SHA256SUMS.json'
    if not p.exists():raise SystemExit('Release manifest missing')
    manifest=json.loads(p.read_text(encoding='utf-8'));bad=[]
    for rel,want in manifest['files'].items():
        f=ROOT/rel
        if not f.is_file() or hashlib.sha256(f.read_bytes()).hexdigest()!=want:bad.append(rel)
    if bad:raise SystemExit('MISSING OR CHANGED:\n'+'\n'.join(bad))
    print(f'PASS: {len(manifest["files"])} released files verified; manifest itself excluded.')
if __name__=='__main__':main()
