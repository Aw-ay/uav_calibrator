#ifndef CAL_EVENT_CONTROL_H
#define CAL_EVENT_CONTROL_H
#include <stddef.h>
#include <stdint.h>
#include "include/capture_event.h"
#include "generated/calibrator_contract.h"
typedef enum { CAL_EVENT_OK=0,CAL_EVENT_ARGUMENT,CAL_EVENT_SHORT,CAL_EVENT_SCHEMA,CAL_EVENT_RESERVED,CAL_EVENT_VALUE,CAL_EVENT_EMPTY,CAL_EVENT_IO_READ,CAL_EVENT_IO_LATCH,CAL_EVENT_IO_POP } cal_event_status;
typedef struct {
 uint32_t flags,config_id,width_ticks,peak_power,selected_range;
 uint64_t pulse_id,owner_epoch,toa_gsc,energy_sum;
} cal_event;
/* Callbacks return zero only on completed ordered transfer; offset is not an address.
 * Caller serializes the entire transaction against other consumers and reset. */
typedef struct {
 void *context;
 int (*read32)(void *context,uint32_t offset,uint32_t *value);
 int (*write32)(void *context,uint32_t offset,uint32_t value);
} cal_event_io;
cal_event_status cal_event_decode(const void *bytes,size_t size,cal_event *out);
cal_event_status cal_event_read_next(const cal_event_io *io,cal_event *out);
#endif
