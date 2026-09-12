#ifndef CAL_FAULT_EVENT_DECODE_H
#define CAL_FAULT_EVENT_DECODE_H
#include <stdint.h>
#include <stddef.h>
#include "fault_event.h"
#include "instrument_control.h"
typedef enum {CAL_FE_OK=0,CAL_FE_ARGUMENT,CAL_FE_SHORT,CAL_FE_SCHEMA,CAL_FE_RESERVED,CAL_FE_VALUE} cal_fault_event_status;
typedef struct {
 uint32_t flags,occurrences,snapshot_flags,config_id,rf_state,normalized_inputs,logical_outputs;
 uint64_t observation_gsc;
} cal_fault_event;
/* Decode one64-byte record; output unchanged on failure. No POP/MMIO or retry.
 * Count saturation marks a lower bound; snapshot is the first observation. */
cal_fault_event_status cal_fault_event_decode(const void *,size_t,cal_fault_event *);
#endif
