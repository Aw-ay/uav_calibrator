#ifndef CAL_UNIFIED_EVENT_READER_H
#define CAL_UNIFIED_EVENT_READER_H
#include "../event_control.h"
#include "fault_event_decode.h"
#include "tx_lifecycle_decode.h"
typedef enum {CAL_UE_OK=0,CAL_UE_ARGUMENT,CAL_UE_EMPTY,CAL_UE_BUSY,
 CAL_UE_IO_COUNT,CAL_UE_IO_LATCH,CAL_UE_IO_READ,CAL_UE_UNSUPPORTED,
 CAL_UE_INVALID_RECORD,CAL_UE_POP_UNCERTAIN,CAL_UE_NOT_LATCHED} cal_unified_event_status;
typedef enum {CAL_UE_IDLE=0,CAL_UE_SNAPSHOT,CAL_UE_UNCERTAIN} cal_unified_event_state;
typedef enum {CAL_UE_RAW=0,CAL_UE_CAPTURE,CAL_UE_FAULT,CAL_UE_TX} cal_unified_event_kind;
typedef struct {
 cal_unified_event_state state;
 cal_unified_event_kind kind;
 int decode_status;
 uint8_t raw[EVENT_BYTES];
 union {cal_event capture;cal_fault_event fault;cal_tx_lifecycle_event tx;} decoded;
} cal_unified_event_reader;
/* Single owner must serialize fetch/inspect/pop and coordinate queue reset.
 * Callbacks return zero only for completed, ordered hardware operations.
 * fetch retains every complete snapshot, including unknown/malformed records;
 * it never POPs. decoded is usable only after CAL_UE_OK. Failed reads leave
 * reader unchanged and can be retried under the ownership/reset contract.
 * pop explicitly discards the retained record, including malformed records.
 * Any nonzero POP callback enters UNCERTAIN: neither operation retries IO.
 * Reinitialize only after external reconciliation or a coordinated queue reset,
 * never as an automatic retry. COUNT cannot resolve ambiguous POP completion.
 * This is a portable reader, not a production MMIO/GIC adapter. */
void cal_unified_event_init(cal_unified_event_reader *);
cal_unified_event_status cal_unified_event_fetch(const cal_event_io *,cal_unified_event_reader *);
cal_unified_event_status cal_unified_event_pop(const cal_event_io *,cal_unified_event_reader *);
#endif
