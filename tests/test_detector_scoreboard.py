"""Real RTL scoreboard plus isolated mutation checks; never edit production RTL."""
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / 'rtl/capture/pulse_detector.sv'
TB = ROOT / 'tb/system/tb_detector_scoreboard.sv'

def simulate(source, directory):
    rtl = directory / 'detector.sv'
    rtl.write_text(source, encoding='utf-8')
    image = directory / 'sim.vvp'
    result = subprocess.run(['C:/iverilog/bin/iverilog.exe', '-g2012',
        '-s', 'tb_detector_scoreboard', '-o', str(image), str(rtl), str(TB)],
        capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return subprocess.run(['C:/iverilog/bin/vvp.exe', str(image)],
                          capture_output=True, text=True, timeout=60)

if __name__ == '__main__':
    source = RTL.read_text()
    results = []
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        good = simulate(source, directory)
        assert good.returncode == 0 and 'PASS detector scoreboard' in good.stdout, good.stdout + good.stderr
        results.append(dict(case='production', status='PASS', output=good.stdout))
        for name, old, new, reason in [
            ('strict_on_comparator', 'sample_power>=cfg_on_power', 'sample_power>cfg_on_power', 'on threshold onset'),
            ('inclusive_tail', "event_end_seq<=last_body_seq+64'd1", 'event_end_seq<=last_body_seq', 'exclusive end excludes hold'),
            ('lost_source_fault', "(!source_valid?SOURCE_BAD:4'd0)", "4'd0", 'invalid source abort'),
        ]:
            assert old in source
            bad = simulate(source.replace(old, new), directory)
            assert bad.returncode != 0 and reason in bad.stdout, name + ': ' + bad.stdout + bad.stderr
            results.append(dict(case=name, status='MUTATION_DETECTED', output=bad.stdout))
    (ROOT / 'reports/detector_scoreboard.json').write_text(json.dumps(results, indent=2))
    print(good.stdout, end='')
    print('PASS 3 isolated RTL mutations detected')
