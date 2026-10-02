# D05 online statistics integration boundary

The standalone `online_body_statistics` primitive and its causal Python reference
are implemented and tested. They are not connected to the active capture path.
See `contracts/online_body_statistics.json` for exact widths and boundaries.

The current `receive_event_producer` emits `eop_event_stop` only after the frozen
post window has become available. Its value is `det_end_seq + posts[slot]`.
It cannot serve as the body end, nor as a bounded-latency EOP notification.

Add a separate immutable body-end event at the real `det_event && detector_bound`
edge, carrying owner epoch, pulse ID, detector `det_end_seq` exclusive, precision
and reason. Preserve the existing capture-stop event and RAW extent unchanged.
An accepted onset and its frozen noise must reserve an online statistics context.
Do not infer body end from a requested DMA length, from the current post register,
or from a later Fine result.

Use one shared six-channel power pipeline and a bounded causal commit buffer;
defer updates until an EOP with hold <=256 plus explicit producer pipeline latency
can exclude confirmation samples. Several independent contexts may share the
delayed power stream. No A-port read and no captured-IQ bank copy are needed.
Context identity, missing samples, sequence discontinuities, late EOP, overflow,
and unsupported hold must fail qualification explicitly, not silently shorten
the pulse or fall back to A scanning.

The package uses two notations for TOP. Resolve this as `top_signal` being the
maximum four-sample moving average of `max(power-noise,0)`; the Fine threshold
is `noise + top_signal/2`. Do not subtract noise twice. Raw peak is separate.
All initial context and end events are real-time observations; no future EOP is
available to a reference model until the actual event arrives.

Required independent vectors: hold 1/125/256 and reject257; short body <4;
overshoot and ringing; high confirmation/post samples excluded from body; H/V
different envelopes; exact onset/end boundaries; missing samples; four contexts;
held result and saturated admission; sequence and owner rollover guards.
The primitive uses a shared 272-cycle POWER delay (256 hold +16 transport budget),
four retained contexts, complete four-point averages and 46-bit energy. An external
IQ square pipeline must provide six powers <=2^31. Admission rejects hold257;
duplicate identity, wrong owner end, late/oversize end, gaps, overflow, cold reset
and sequence rollover have directed tests. At the initial standalone stage, real producer timing was unbound; see the integration update below.

Only after integration tests pass may normal `scan_ready` admission be removed and the old
248.008us diagnostic scan budget replaced in the live replay software planner.

## Integration completed 2026-09-30

`receive_event_producer` now emits a separate body-end event at detector confirmation,
with full epoch/pulse identity, precision and reason. Its existing POST capture-stop
remains unchanged. Configuration hold0 resolves to125, hold>256 is refused by the
instrument CONFIG validator and detector producer.

`capture_online_statistics` binds a shared two-stage six-channel IQ power pipeline
and four retained statistics contexts. Capture and statistics reserve on the same
accepted onset. Duplicate keys/full contexts block new admission, never ADC input.
Producer errors cancel by full key; canceled active contexts drain through their
end/error result before release. Qualification queries by epoch/pulse, validates
all three live bank generations and window geometry, and consumes the retained
result only with accepted admission. The normal instrument enables ONLINE_STATS=1;
A-port statistics enable/address are tied zero and the capture RAM statistics port
is disabled. ONLINE_STATS=0 exists only for explicit legacy diagnostic/test use.

The instrument integration independently compares RAW CRC and every actual FIR
sample, then computes PDW body energy/peak/width from the observed exclusive body
interval. Legacy qualified PDW binary layout is unchanged, but its statistics now
mean body rather than RAW PRE/POST; both legacy and unified queues use BODY_STATS=1.
The Fine 128-byte format/queue remains separate and unimplemented in this path.

A conservative statistics availability bound is body_end GSC +275 RF clocks
(2 IQ-power stages +272 commit delay +1 observation edge), or 2.200 microseconds.
Readiness is max(this time, actual RAW PENDING), plus bounded admission/publish
latencies. This is not total DRFM latency. New online C APIs implement that join;
old APIs are explicitly labeled diagnostic A-scan only. All queue, submit, release,
continuous-sample and downstream bounds remain mandatory; Fine analysis ownership
is not yet included. TOP remains implemented/tested in the primitive but its unused
logic is pruned in this qualification-only wrapper until the Fine consumer exists.

Actual detector tests cover hold1/125/256/default0, short bodies1/3/4, and14999 samples;
body-end transport is at most two clocks beyond hold, and results meet the275-clock
bound before a500-sample POST completes. Power tests cover randomized signed IQ and
-32768 extrema. Four-context reservation/duplicate/backpressure/cancel tests pass.
