"""Executable behavioral reference for the proposed pulse-bank contract.

This is NOT RTL, an AMD RAM timing model, an RFDC model, or a CDC simulation.
Inputs carry an absolute 125 MS/s sample index; each tick represents one time slot.
The model stores quality sidecars for auditability; physical sidecar RAM is extra.
External callers must have quiesced all hardware consumers before quiesced_reset.
"""
from __future__ import annotations
from dataclasses import dataclass
import math
from typing import Iterable

@dataclass(frozen=True)
class Token:
    owner_epoch: int
    group: int
    bank: int
    generation: int


def budget(depth: int, banks: int, groups: int, sample_hz: int) -> dict:
    if depth < 2 or depth & (depth - 1) or min(banks, groups, sample_hz) <= 0:
        raise ValueError('Invalid size or sample frequency')
    return dict(bank_bytes=8*depth, raw_bytes=8*depth*banks*groups,
                bank_duration_us=depth/sample_hz*1e6,
                address_bits=(depth-1).bit_length(), sample_count_bits=depth.bit_length(),
                group_write_bytes_per_second=8*sample_hz,
                input_bytes_per_second=8*sample_hz*groups)


class Bank:
    MUTABLE = {'ARMING', 'ARMED', 'CAPTURE'}

    def __init__(self, depth: int, pre: int, max_detector_delay: int,
                 group: int = 0, bank: int = 0):
        if depth < 2 or depth & (depth-1):
            raise ValueError('depth must be an even power of two')
        if pre < 0 or max_detector_delay < 0 or pre+max_detector_delay+1 > depth:
            raise ValueError('history requirement does not fit')
        self.depth, self.pre = depth, pre
        self.max_detector_delay = max_detector_delay
        self.group, self.bank = group, bank
        self.owner_epoch = 0
        self.generation = 0
        self.latest = -1
        self.data = [0] * depth
        self.tags = [-1] * depth  # software scoreboard only; not proposed per-word RTL tags
        self.quality = [0] * depth
        self._rearm()

    @property
    def token(self) -> Token:
        return Token(self.owner_epoch, self.group, self.bank, self.generation)

    @property
    def count(self) -> int:
        return 0 if self.start_seq is None or self.end_seq is None else self.end_seq-self.start_seq

    def _rearm(self) -> None:
        self.state = 'ARMING'
        self.history_count = 0
        self.start_seq = None
        self.end_seq = None
        self.requested_end = None
        self.refs: set[str] = set()
        self.errors: set[str] = set()
        self.quality_or = 0

    def tick(self, seq: int, word: int, quality: int = 0) -> None:
        if seq != self.latest + 1:
            raise ValueError('Every sample time must be represented, including invalid slots')
        if not 0 <= word < (1 << 64):
            raise ValueError('A stored H/V time sample must fit 64 bits')
        self.latest = seq
        if self.state not in self.MUTABLE:
            return
        if self.state == 'CAPTURE' and seq >= self.start_seq+self.depth:
            raise AssertionError('Capacity guard should have frozen before overwrite')
        addr = seq & (self.depth-1)
        self.data[addr], self.tags[addr], self.quality[addr] = word, seq, quality
        self.history_count = min(self.depth, self.history_count+1)
        if self.state == 'ARMING' and self.history_count >= self.pre+self.max_detector_delay+1:
            self.state = 'ARMED'
        if self.state == 'CAPTURE':
            if self.requested_end is not None and seq+1 >= self.requested_end:
                self._freeze(self.requested_end)
            elif seq+1 >= self.start_seq+self.depth:
                self.errors.add('TRUNCATED')
                self._freeze(self.start_seq+self.depth)

    def can_reserve(self, onset: int) -> bool:
        if self.state != 'ARMED' or not 0 <= self.latest-onset <= self.max_detector_delay:
            return False
        start = onset-self.pre
        if start < 0 or self.latest-start+1 > self.history_count:
            return False
        return self.tags[start & (self.depth-1)] == start

    def reserve(self, onset: int) -> Token:
        if not self.can_reserve(onset):
            raise ValueError('No armed bank with the required fresh, time-aligned history')
        self.generation += 1
        self.start_seq = onset-self.pre
        self.state = 'CAPTURE'
        self.errors.clear()
        return self.token

    def set_end(self, end_exclusive: int) -> None:
        if self.state != 'CAPTURE':
            raise RuntimeError('Window end is accepted only while capturing')
        if not self.start_seq < end_exclusive <= self.start_seq+self.depth:
            raise ValueError('Record length exceeds bank capacity or is empty')
        if self.tags[self.start_seq & (self.depth-1)] != self.start_seq:
            raise RuntimeError('Pretrigger data already overwritten')
        self.requested_end = end_exclusive
        if end_exclusive <= self.latest+1:
            self._freeze(end_exclusive)

    def _freeze(self, end_exclusive: int) -> None:
        self.end_seq = end_exclusive
        self.state = 'FROZEN_PENDING'
        # Hardware accumulators/sidecars must reproduce this after their latency drains.
        self.quality_or = 0
        for seq in range(self.start_seq, self.end_seq):
            addr = seq & (self.depth-1)
            if self.tags[addr] != seq:
                raise AssertionError('Frozen record contains stale or overwritten data')
            self.quality_or |= self.quality[addr]

    def finalize(self, consumers: Iterable[str], extra_errors: Iterable[str] = ()) -> None:
        if self.state != 'FROZEN_PENDING':
            raise RuntimeError('Cannot publish before final sample is committed')
        refs = set(consumers)
        if refs - {'record', 'replay'}:
            raise ValueError('Only baseline consumers are modelled')
        self.errors.update(extra_errors)
        if 'replay' in refs and (self.errors or self.quality_or):
            raise ValueError('Invalid/truncated record is not approved for replay')
        self.refs = refs  # reserved BEFORE any descriptor could be observed downstream
        self.state = 'FROZEN'
        if not refs:
            self._rearm()

    def ack(self, token: Token, consumer: str) -> bool:
        if self.state != 'FROZEN' or token != self.token or consumer not in self.refs:
            return False
        self.refs.remove(consumer)
        if not self.refs:
            self._rearm()
        return True

    def words(self) -> list[int]:
        if self.state != 'FROZEN':
            raise RuntimeError('Unpublished bank may not be consumed')
        return [self.data[seq & (self.depth-1)] for seq in range(self.start_seq,self.end_seq)]

    def payload_beats(self) -> list[tuple[int,int,bool]]:
        """128-bit payload-only readout. Odd starts use adjacent aligned RAM words.
        TLAST here means payload completion. The external formatter owns RECORD TLAST.
        """
        if self.state != 'FROZEN':
            raise RuntimeError('Bank is not published')
        def read_b(word_addr):
            first = 2*(word_addr % (self.depth//2))
            return self.data[first] | (self.data[first+1] << 64)
        out = []
        for offset in range(0, self.count, 2):
            addr = (self.start_seq+offset) & (self.depth-1)
            aligned = addr//2
            first = read_b(aligned)
            if addr & 1:
                second = read_b(aligned+1)
                packed = (first >> 64) | ((second & ((1<<64)-1)) << 64)
            else:
                packed = first
            n = min(2, self.count-offset)
            if n == 1: packed &= (1<<64)-1
            out.append((packed, 0xffff if n == 2 else 0xff, offset+n == self.count))
        return out

    def quiesced_reset(self, new_epoch: int) -> None:
        if new_epoch <= self.owner_epoch:
            raise ValueError('Reset epoch must increase')
        self.owner_epoch = new_epoch
        self.generation = 0
        self._rearm()  # leave physical RAM intact, but make all previous contents unavailable


def reserve_main(banks: list[Bank], onset: int) -> bool:
    if len(banks) != 3 or [b.group for b in banks] != [0,1,2]:
        raise ValueError('Require one candidate from each primary range group')
    if not all(b.can_reserve(onset) for b in banks):
        return False
    for bank in banks: bank.reserve(onset)
    return True


def select_range(hv_valid_in_descending_gain: list[tuple[bool,bool]]) -> int | None:
    for idx, (h_valid, v_valid) in enumerate(hv_valid_in_descending_gain):
        if h_valid and v_valid: return idx
    return None


class PayloadSource:
    """Transaction-level AXIS stability model. No RAM latency or CDC is modelled."""
    def __init__(self, beats):
        self.beats = list(beats)
        self.index = 0
    def peek(self):
        return self.beats[self.index] if self.index < len(self.beats) else None
    def step(self, ready: bool):
        value = self.peek()
        if ready and value is not None: self.index += 1
        return value
