#ifndef CAL_CAPTURE_BUDGET_H
#define CAL_CAPTURE_BUDGET_H
#include <stdint.h>
/* All durations are 500 MHz GSC ticks. Planning only: live PL qualification,
 * lease, identity, grid and safety checks remain mandatory at dispatch. */
typedef struct {
    uint32_t sample_count,pre_samples,reference_index,bounds_valid;
    uint32_t detector_latency_cycles;
    uint64_t pending_gsc,scan_wait_ticks,publish_ticks;
    uint64_t submit_ticks; /* bounded PS/MMIO/CDC/queue admission after ready */
    /* Relative to ready_gsc; include complete ACK/return processing, not start. */
    uint64_t upload_release_ticks,replay_release_ticks;
    uint64_t downstream_ticks,target_gsc;
} cal_capture_budget_input;
typedef struct {
    uint64_t scan_ticks,ready_gsc,earliest_target_gsc,rearm_gsc;
} cal_capture_budget;
enum {CAL_BUDGET_OK=0,CAL_BUDGET_INVALID=1,CAL_BUDGET_UNBOUNDED=2,
      CAL_BUDGET_OVERFLOW=3,CAL_BUDGET_LATE=4};
/* Legacy diagnostic scan model, not the v0.6 instrument normal path. */
int cal_capture_budget_plan(const cal_capture_budget_input *,cal_capture_budget *);
/* Normal v0.6 path: body_end_gsc is exclusive and excludes POST. Requires
 * continuous 125 MHz sequence, resolved hold<=256, and finite caller bounds.
 * scan_wait_ticks is the bounded qualification admission queue wait in this API.
 * scan_ticks returns zero. Readiness waits for BOTH RAW PENDING and body stats.
 * Fine analysis ownership is not implemented/included in this model yet. */
int cal_capture_budget_plan_online(const cal_capture_budget_input *,uint64_t body_end_gsc,cal_capture_budget *);
#endif
