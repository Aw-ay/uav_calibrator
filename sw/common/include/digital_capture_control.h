#ifndef CAL_DIGITAL_CAPTURE_CONTROL_H
#define CAL_DIGITAL_CAPTURE_CONTROL_H
#include "command_control.h"
#include "capture_budget.h"
/* Serialized task is 48 little-endian words. This helper is a planning gate,
 * followed by the normal asynchronous command submission. It does not replace
 * live PL ownership/qualification/deadline checks or promise RF emission.
 * Caller supplies certified finite queue, publish, submit and release bounds;
 * count, reference index and target are taken from the actual task words. */
/* Diagnostic legacy A-scan only; normal v0.6 uses the online helper below. */
cal_command_status cal_replay_budgeted_begin(const cal_command_io *,uint32_t,
    const uint32_t task[48],const cal_capture_budget_input *,cal_capture_budget *,int *budget_reason);
/* body_end_gsc must refer to this pulse, exclude POST, and use the same GSC epoch. */
cal_command_status cal_replay_budgeted_begin_online(const cal_command_io *,uint32_t,
    const uint32_t task[48],const cal_capture_budget_input *,uint64_t body_end_gsc,cal_capture_budget *,int *budget_reason);
cal_command_status cal_aux_capture_begin(const cal_command_io *,uint32_t,uint32_t count,uint64_t tx_token);
cal_command_status cal_aux_meta_peek_begin(const cal_command_io *,uint32_t);
cal_command_status cal_aux_meta_pop_begin(const cal_command_io *,uint32_t,uint32_t metadata_id,uint32_t epoch_id);
#endif
