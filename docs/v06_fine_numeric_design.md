# Fine numerical reference and shared phase kernel

The active design input is the immutable v0.6 package. This stage freezes mathematical
and integer behavior before the single-pass hardware engine. It does not implement
Fine job ownership, bank arbitration, result transport or all V70–V74 acceptance.

## Three verification layers

- `tools/fine_reference.py`: floating-point batch mathematical reference. Independent
  sample-angle unwrap/quadratic fitting checks frequency and chirp against segment
  sums. Analytic power ramps independently define H/V edge timing.
- `tools/fine_fixed.py`: integer batch composition, bounded rational edge variance,
  explicit rounding/saturation/overflow, segment accumulators, integer least-squares
  and Q31 CORDIC. It has no cycle or one-pass claim.
- `rtl/fine/fine_cordic.sv`: the shared FINALIZE phase kernel only, with exact integer
  vectors, request/result ownership, reset and output backpressure verification.

The floating model uses N+TOP_signal/2. The integer model uses N+(TOP_signal>>1);
this is an explicit half-power threshold quantization, not a second noise subtraction.
Local eight-point fits use k-3 through k+4 (at least four samples if clipped by RAW).
Rise uses the first valid bracket; fall the last in a frozen +/-8-sample neighborhood.
Wrong slope or root outside the bracket is invalid. Variance fusion ignores covariance
between the two estimates and is an engineering estimator, not a calibrated confidence
interval. Overflow invalidates instead of clipping a timestamp into validity.

Frequency is residual complex-baseband frequency extrapolated to RAW sample zero,
which corresponds to gsc_first. Chirp is Hz/s. Eight segment boundaries come from the
frozen coarse interval before the RAM read; actual populated pair centers are accumulated.
This avoids requiring the final falling edge to be known before defining segment bins.
At least nine stable samples and two populated bins are needed. Large segment phase
jumps, near-Nyquist ambiguity, zero sums and low coherence invalidate spectral fields.
Input alias order cannot be recovered from sampled IQ without physical binding knowledge.
H/V phase uses H*conj(V) over the intersection of the independent stable bodies;
coherence normalization uses separate H/V energies so unequal gains do not imply failure.

## Integer phase kernel

Signed48 complex sums are normalized to highest magnitude bit44, then vectored through
31 shift-add iterations. Vector registers are signed48; phase accumulation is signed33.
Output is signed turns times 2^31, canonical [-2^30,2^30). Zero vectors return explicit
invalid status. Nonzero requests present a held result 33 clocks after acceptance;
zero is reported on the acceptance edge. No next request is accepted until the previous
result has been consumed. Cold reset cancels an in-flight result.

1007 RTL vectors match the integer model exactly, including signed48 extrema, all
quadrants, zero, reset and stalls. An independent atan2 oracle over2006 vectors finds
maximum error6 Q31-turn LSB; this is numerical error, not physical phase accuracy.
The 200MHz module OOC has WNS+1.758ns/WHS+0.072ns/WPWS+2.225ns, all failing endpoints0,
1586 LUT/381 FF/0 BRAM/0 DSP. It is not the resource or timing result of the full Fine engine.

## Next hardware gate

Update 2026-09-30: the causal32-sample schedule model, cache RTL and H/V sufficient
statistics accumulator are now verified separately; see v06_fine_stream_design.md.
The edge service in that model is ideal arithmetic with explicit stalls; edge/LS
hardware and the full causal RTL controller are still pending. The following
paragraph describes the original gate, now partially met.

Prove a single-pass natural-B128 parser and 16–32-sample local buffer model without
future reads. Model edge-finalization stalls explicitly, then map edge arithmetic and
segment/LS FINALIZE into shared hardware. All three ranges share one H/V engine;
analysis/upload/replay references and per-bank B arbitration must be integrated before
claiming Fine delivery. TOP priors are not yet retained for a hardware Fine consumer.
