"""Independent checks for the pre-decimation four-SPC overload monitor."""
import pathlib
import random
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
IV = pathlib.Path("C:/iverilog/bin/iverilog.exe")
VVP = IV.with_name("vvp.exe")


def abs16(value):
    return 32768 if value == -32768 else abs(value)


def reference(i_words, q_words, pair_valid, thresholds, threshold_valid, hard_event, hard_known):
    near = counts = 0
    for channel in range(8):
        if pair_valid >> channel & 1 and threshold_valid >> channel & 1 and 1 <= thresholds[channel] <= 32768:
            count = sum(
                abs16(i_words[channel][lane]) >= thresholds[channel]
                or abs16(q_words[channel][lane]) >= thresholds[channel]
                for lane in range(4)
            )
            counts |= count << (3 * channel)
            near |= bool(count) << channel
    return near, counts, (~pair_valid) & 0xFF, ((~threshold_valid) | sum((not 1 <= t <= 32768) << c for c, t in enumerate(thresholds))) & 0xFF, hard_event & hard_known, (~hard_known) & 0xFF


def pack(words):
    value = 0
    for channel in range(8):
        for lane in range(4):
            value |= (words[channel][lane] & 0xFFFF) << (channel * 64 + lane * 16)
    return value


class NativeOverloadTests(unittest.TestCase):
    def compile_run(self, tb):
        with tempfile.TemporaryDirectory() as tmp:
            out = pathlib.Path(tmp) / "sim.vvp"
            result = subprocess.run([str(IV), "-g2012", "-s", "tb_native_overload_monitor", "-o", str(out), str(ROOT / "rtl/frontend/native_overload_monitor.sv"), str(tb)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(VVP), str(out)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return result.stdout

    def test_directed_rtl(self):
        stdout = self.compile_run(ROOT / "tb/unit/tb_native_overload_monitor.sv")
        self.assertIn("PASS native_overload_monitor", stdout)

    def test_200_independent_random_vectors(self):
        rng = random.Random(0x8ADC4)
        vectors = []
        for n in range(200):
            iw = [[rng.randint(-32768, 32767) for _ in range(4)] for _ in range(8)]
            qw = [[rng.randint(-32768, 32767) for _ in range(4)] for _ in range(8)]
            pv, tv, he, hk = (rng.randrange(256) for _ in range(4))
            th = [rng.choice([0, 1, 8192, 16384, 30000, 32768, 32769, 65535, 131071]) for _ in range(8)]
            vectors.append((pack(iw), pack(qw), pv, th, tv, he, hk, reference(iw, qw, pv, th, tv, he, hk)))
        lines = ["`timescale 1ns/1ps", "module tb_native_overload_monitor;", "reg clk=0; always #4 clk=~clk; reg rst=1,in_valid=0; reg [511:0] iq_i,iq_q; reg [7:0] iq_valid,threshold_validated,hard_overrange_event,hard_overrange_known; reg [135:0] near_clip_threshold; reg [63:0] gsc_base,beat_seq; wire out_valid; wire [63:0] out_gsc_base,out_beat_seq; wire [7:0] near_clip,missing,threshold_unknown,hard_overrange,hard_overrange_unknown; wire [23:0] near_clip_count; native_overload_monitor dut(.*);", "initial begin @(posedge clk);#1;rst=0;"]
        for n, (ii, qq, pv, th, tv, he, hk, expected) in enumerate(vectors):
            threshold = sum(t << (17*c) for c, t in enumerate(th))
            near, counts, missing, unknown, hard, hard_unknown = expected
            lines.append(f"@(negedge clk);in_valid=1;gsc_base=64'h{n*4:016x};beat_seq=64'h{n:016x};iq_i=512'h{ii:0128x};iq_q=512'h{qq:0128x};iq_valid=8'h{pv:02x};near_clip_threshold=136'h{threshold:034x};threshold_validated=8'h{tv:02x};hard_overrange_event=8'h{he:02x};hard_overrange_known=8'h{hk:02x};@(posedge clk);#1;if(!out_valid||out_gsc_base!==64'h{n*4:016x}||out_beat_seq!==64'h{n:016x}||near_clip!==8'h{near:02x}||near_clip_count!==24'h{counts:06x}||missing!==8'h{missing:02x}||threshold_unknown!==8'h{unknown:02x}||hard_overrange!==8'h{hard:02x}||hard_overrange_unknown!==8'h{hard_unknown:02x})$fatal(1,\"random {n}\");")
        lines.append("$display(\"PASS random native_overload_monitor\");$finish;end endmodule")
        with tempfile.TemporaryDirectory() as tmp:
            tb = pathlib.Path(tmp) / "tb.sv"
            tb.write_text("\n".join(lines))
            self.assertIn("PASS random", self.compile_run(tb))


if __name__ == "__main__":
    unittest.main()
