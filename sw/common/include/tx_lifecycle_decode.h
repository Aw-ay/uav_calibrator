#ifndef CAL_TX_LIFECYCLE_DECODE_H
#define CAL_TX_LIFECYCLE_DECODE_H
#include <stdint.h>
#include <stddef.h>
#include "tx_lifecycle_event.h"
typedef enum {CAL_TX_OK=0,CAL_TX_ARGUMENT,CAL_TX_SHORT,CAL_TX_SCHEMA,CAL_TX_RESERVED,CAL_TX_VALUE} cal_tx_lifecycle_status;
typedef struct {
 uint32_t flags,source,reason,command_sequence,config_id;
 uint64_t token,accept_gsc,drain_gsc,retire_gsc;
} cal_tx_lifecycle_event;
/* Pure decoder; output unchanged on error. SINK_CONFIRMED is the logical
 * exact-token receiver acknowledgement, never evidence of analog RF output. */
cal_tx_lifecycle_status cal_tx_lifecycle_decode(const void *,size_t,cal_tx_lifecycle_event *);
#endif
