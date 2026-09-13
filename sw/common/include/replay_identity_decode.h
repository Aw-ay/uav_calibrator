#ifndef CAL_REPLAY_IDENTITY_DECODE_H
#define CAL_REPLAY_IDENTITY_DECODE_H
#include <stdint.h>
#include <stddef.h>
#include "replay_identity_event.h"
typedef enum {CAL_RI_OK=0,CAL_RI_ARGUMENT,CAL_RI_SHORT,CAL_RI_SCHEMA,CAL_RI_RESERVED,CAL_RI_VALUE} cal_replay_identity_status;
typedef struct {
 uint64_t token,task_id,pulse_id,owner_epoch,generation;
 uint32_t config_id,fir_id,source_epoch;
 uint16_t group,bank;
} cal_replay_identity;
/* Identity only. Match a separate REPLAY retirement by token within the same
 * coordinated reset domain. Output remains unchanged on decode failure. */
cal_replay_identity_status cal_replay_identity_decode(const void *,size_t,cal_replay_identity *);
#endif
