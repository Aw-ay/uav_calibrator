"""Behavioral contract tests; not a hardware/CDC simulation."""
import importlib.util
import pathlib
import random
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'models'))

class RingTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(importlib.util.find_spec('ring_model'),
                             'Behavioral implementation is not present yet')
        import ring_model
        self.m = ring_model

    def bank(self, depth=64, pre=4, delay=3, group=0, bankslot=0):
        return self.m.Bank(depth, pre, delay, group, bankslot)

    def feed(self, b, stop, flag_at=None):
        for seq in range(b.latest + 1, stop):
            b.tick(seq, seq + 100, int(seq == flag_at))

    def frozen(self, onset=30, end=43, depth=64, pre=4, delay=3, refs=('record', 'replay')):
        b = self.bank(depth, pre, delay)
        self.feed(b, onset + delay + 1)
        b.reserve(onset)
        b.set_end(end)
        self.feed(b, end)
        b.finalize(refs)
        return b

    def test_01_dimensions_and_bank_count(self):
        x = self.m.budget(16384, 4, 4, 125_000_000)
        self.assertEqual(x['bank_bytes'], 131072)
        self.assertEqual(x['raw_bytes'], 2097152)
        self.assertAlmostEqual(x['bank_duration_us'], 131.072)
        self.assertEqual(x['sample_count_bits'], 15)

    def test_02_arming_requires_history_and_detector_delay(self):
        b = self.bank(pre=4, delay=3)
        self.feed(b, 7)
        self.assertEqual(b.state, 'ARMING')
        self.feed(b, 8)
        self.assertEqual(b.state, 'ARMED')

    def test_03_trigger_time_not_arrival_pointer(self):
        b = self.frozen(onset=100, end=120)
        self.assertEqual(b.start_seq, 96)
        self.assertEqual(b.words(), list(range(196, 220)))

    def test_04_odd_start_and_wrap_payload(self):
        b = self.frozen(onset=65, end=76, pre=4)
        self.assertEqual(b.start_seq % 64, 61)
        self.assertEqual(b.words(), list(range(161, 176)))
        beats = b.payload_beats()
        blob = b''.join(w.to_bytes(16, 'little')[:k.bit_count()] for w, k, _ in beats)
        want = b''.join(w.to_bytes(8, 'little') for w in b.words())
        self.assertEqual(blob, want)
        self.assertEqual(beats[-1][1], 0x00ff)

    def test_05_capture_full_is_not_zero_length(self):
        b = self.frozen(onset=20, end=80, depth=64, pre=4)
        self.assertEqual(b.count, 64)
        self.assertNotIn('TRUNCATED', b.errors)
        self.assertEqual((b.start_seq + b.count) % 64, b.start_seq % 64)

    def test_06_reject_oversize_window(self):
        b = self.bank()
        self.feed(b, 24)
        b.reserve(20)
        with self.assertRaises(ValueError):
            b.set_end(90)

    def test_07_missing_eop_stops_before_overwrite(self):
        b = self.bank()
        self.feed(b, 24)
        b.reserve(20)
        self.feed(b, 150)
        self.assertEqual(b.state, 'FROZEN_PENDING')
        self.assertIn('TRUNCATED', b.errors)
        b.finalize(('record',))
        self.assertEqual(b.words(), list(range(116, 180)))

    def test_08_wait_for_quality_before_publication(self):
        b = self.bank()
        self.feed(b, 24)
        b.reserve(20)
        b.set_end(30)
        self.feed(b, 30)
        self.assertEqual(b.state, 'FROZEN_PENDING')
        with self.assertRaises(RuntimeError):
            b.words()
        b.finalize(('record',))
        self.assertEqual(b.state, 'FROZEN')

    def test_09_both_consumers_must_release(self):
        b = self.frozen()
        token = b.token
        self.assertTrue(b.ack(token, 'record'))
        self.assertEqual(b.state, 'FROZEN')
        self.assertEqual(b.refs, {'replay'})
        self.assertTrue(b.ack(token, 'replay'))
        self.assertEqual(b.state, 'ARMING')

    def test_10_duplicate_ack_does_not_free_other_reference(self):
        b = self.frozen()
        token = b.token
        self.assertTrue(b.ack(token, 'record'))
        self.assertFalse(b.ack(token, 'record'))
        self.assertEqual(b.refs, {'replay'})

    def test_11_stale_generation_cannot_release_new_capture(self):
        b = self.frozen(refs=('record',))
        old = b.token
        b.ack(old, 'record')
        self.feed(b, 80)
        b.reserve(76)
        b.set_end(85)
        self.feed(b, 85)
        b.finalize(('record',))
        self.assertNotEqual(old, b.token)
        self.assertFalse(b.ack(old, 'record'))
        self.assertEqual(b.state, 'FROZEN')

    def test_12_epoch_protects_reset_reuse(self):
        b = self.frozen(refs=('record',))
        old = b.token
        b.quiesced_reset(7)
        self.feed(b, 60)
        b.reserve(56)
        b.set_end(65)
        self.feed(b, 65)
        b.finalize(('record',))
        self.assertFalse(b.ack(old, 'record'))

    def test_13_frozen_memory_immutable(self):
        b = self.frozen()
        before = b.words()
        self.feed(b, 500)
        self.assertEqual(b.words(), before)

    def test_14_release_requires_fresh_prefill(self):
        b = self.frozen(refs=('record',))
        b.ack(b.token, 'record')
        self.assertEqual(b.state, 'ARMING')
        self.assertFalse(b.can_reserve(b.latest))
        self.feed(b, b.latest + 1 + 8)
        self.assertEqual(b.state, 'ARMED')

    def test_15_main_three_group_admission_is_atomic(self):
        bs = [self.bank(group=g) for g in range(3)]
        for b in bs: self.feed(b, 24)
        bs[2].reserve(20)
        state = [b.state for b in bs]
        self.assertFalse(self.m.reserve_main(bs, 20))
        self.assertEqual([b.state for b in bs], state)

    def test_16_main_three_group_success(self):
        bs = [self.bank(group=g) for g in range(3)]
        for b in bs: self.feed(b, 24)
        self.assertTrue(self.m.reserve_main(bs, 20))
        self.assertEqual([b.start_seq for b in bs], [16, 16, 16])

    def test_17_hv_joint_range_choice(self):
        self.assertEqual(self.m.select_range([(False, True), (True, True), (True, True)]), 1)
        self.assertIsNone(self.m.select_range([(False, True), (True, False), (False, False)]))

    def test_18_unselected_discard_does_not_hold_bank(self):
        b = self.frozen(refs=())
        self.assertEqual(b.state, 'ARMING')

    def test_19_quality_is_retained_without_deleting_samples(self):
        b = self.bank()
        self.feed(b, 24, flag_at=18)
        b.reserve(20)
        b.set_end(30)
        self.feed(b, 30, flag_at=28)
        b.finalize(('record',))
        self.assertEqual(len(b.words()), 14)
        self.assertEqual(b.quality_or, 1)

    def test_20_payload_backpressure_is_stable(self):
        b = self.frozen(onset=65, end=100)
        expected = b.payload_beats()
        src = self.m.PayloadSource(expected)
        accepted = []
        rng = random.Random(20260911)
        for _ in range(10000):
            before = src.peek()
            if before is None: break
            ready = rng.random() < 0.35
            value = src.step(ready)
            if ready: accepted.append(value)
            else: self.assertEqual(src.peek(), before)
        self.assertEqual(accepted, expected)
        self.assertTrue(accepted[-1][2])
        self.assertEqual(sum(x[2] for x in accepted), 1)

    def test_21_aux_does_not_consume_primary_bank(self):
        main = [self.bank(group=g) for g in range(3)]
        aux = self.bank(group=3)
        for b in main + [aux]: self.feed(b, 24)
        aux.reserve(20)
        self.assertTrue(self.m.reserve_main(main, 20))
        self.assertEqual(aux.group, 3)

    def test_22_detector_latency_must_be_bounded(self):
        b = self.bank()
        self.feed(b, 40)
        self.assertFalse(b.can_reserve(20))
        with self.assertRaises(ValueError): b.reserve(20)

    def test_23_startup_stale_ram_is_not_valid_history(self):
        b = self.bank()
        self.feed(b, 5)
        self.assertFalse(b.can_reserve(4))

    def test_24_random_wrapped_payloads(self):
        rng = random.Random(19)
        for _ in range(100):
            onset = rng.randrange(10, 400)
            n = rng.randrange(9, 65)
            b = self.frozen(onset=onset, end=onset-4+n)
            expected = list(range(onset-4+100, onset-4+n+100))
            self.assertEqual(b.words(), expected)
            beats = b.payload_beats()
            actual = b''.join(w.to_bytes(16,'little')[:k.bit_count()] for w,k,_ in beats)
            self.assertEqual(actual, b''.join(w.to_bytes(8,'little') for w in expected))

    def test_25_real_profile_124us_record(self):
        b = self.bank(depth=16384, pre=250, delay=32)
        self.feed(b, 20033)
        b.reserve(20000)
        b.set_end(35250)
        self.feed(b, 35250)
        b.finalize(('record', 'replay'))
        self.assertEqual(b.count, 15500)
        self.assertEqual(b.words(), list(range(19850, 35350)))
        self.assertEqual(len(b.payload_beats()), 7750)

    def test_26_delayed_eop_uses_event_time(self):
        b = self.bank()
        self.feed(b, 24)
        b.reserve(20)
        self.feed(b, 35)
        b.set_end(30)  # retrospective exclusive boundary, history remains intact
        b.finalize(('record',))
        self.assertEqual(b.count, 14)
        self.assertEqual(b.words(), list(range(116, 130)))

    def test_27_invalid_record_must_not_replay(self):
        b = self.bank()
        self.feed(b, 24, flag_at=20)
        b.reserve(20)
        b.set_end(30)
        self.feed(b, 30)
        with self.assertRaises(ValueError):
            b.finalize(('replay',))
        self.assertEqual(b.state, 'FROZEN_PENDING')
        b.finalize(('record',))

    def test_28_descriptor_pending_does_not_accept_early_ack(self):
        b = self.bank()
        self.feed(b, 24)
        b.reserve(20)
        b.set_end(30)
        self.feed(b, 30)
        self.assertFalse(b.ack(b.token, 'record'))
        self.assertEqual(b.state, 'FROZEN_PENDING')

if __name__ == '__main__':
    unittest.main(verbosity=2)
