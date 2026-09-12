import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from frame_codec import encode_frame

GCC = pathlib.Path(r"C:/Xilinx/2025.1/tps/mingw/10.0.0/win64.o/nt/bin/gcc.exe")


def build_core_test():
    out = pathlib.Path(tempfile.mkdtemp(prefix="ps_receive_")) / "ps_receive_test.exe"
    sources = [ROOT / "tests" / "ps_receive_core_test.c",
               ROOT / "sw" / "common" / "frame_decode.c",
               ROOT / "sw" / "common" / "dma_slots.c"]
    subprocess.run([str(GCC), "-std=c11", "-Wall", "-Wextra", "-Werror",
                    "-I", str(ROOT / "sw" / "common"), *map(str, sources),
                    "-o", str(out)], check=True)
    return out


def invoke(exe, command, data=b""):
    return subprocess.run([str(exe), command], input=data, capture_output=True)


class PsReceiveCoreTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exe = build_core_test()

    def test_c_decoder_accepts_python_frames(self):
        for trailer in (False, True):
            for header_crc in (False, True):
                for count in (1, 3, 16384):
                    with self.subTest(trailer=trailer, header_crc=header_crc, count=count):
                        samples = ((i % 32768, -(i % 32768), 123, -456) for i in range(count))
                        frame = encode_frame({"format_id": 7, "pulse_id": 0x1122334455667788}, samples,
                                             trailer=trailer, header_crc=header_crc)
                        result = invoke(self.exe, "frame", frame)
                        self.assertEqual(result.returncode, 0, result.stderr.decode())
                        self.assertEqual(result.stdout.decode().split(),
                                         [str(count), str(len(frame)), "123", "-456", str(0x1122334455667788)])

    def test_c_decoder_rejects_corruption_and_wrong_bd_length(self):
        frame = bytearray(encode_frame({"format_id": 1}, [(1, 2, 3, 4)], trailer=True))
        frame[128] ^= 1
        self.assertNotEqual(invoke(self.exe, "frame", frame).returncode, 0)
        good = encode_frame({"format_id": 1}, [(1, 2, 3, 4)], trailer=True)
        self.assertNotEqual(invoke(self.exe, "frame-extra", good + b"x").returncode, 0)

    def test_dma_slot_state_machine_generation_and_reset(self):
        result = invoke(self.exe, "slots")
        self.assertEqual(result.returncode, 0, result.stderr.decode())

    def test_dma_rejects_overlaps(self):
        result = invoke(self.exe, "overlap-regression")
        self.assertEqual(result.returncode, 0, result.stderr.decode())

    def test_dma_rejects_metadata_extent_overflow(self):
        result = invoke(self.exe, "overflow-regression")
        self.assertEqual(result.returncode, 0, result.stderr.decode())


if __name__ == "__main__":
    unittest.main()
