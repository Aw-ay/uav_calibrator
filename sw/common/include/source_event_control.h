#ifndef CAL_SOURCE_EVENT_CONTROL_H
#define CAL_SOURCE_EVENT_CONTROL_H
#include "command_control.h"
#include "instrument_control.h"
typedef struct {
 uint32_t count,dropped;uint64_t token;
 uint32_t source,reason,command_sequence,config_id,flags;
 uint64_t accept_gsc,drain_gsc;
} cal_source_event_snapshot;
typedef enum {CAL_SOURCE_OK=0,CAL_SOURCE_EMPTY,CAL_SOURCE_ARGUMENT,CAL_SOURCE_COMMAND,CAL_SOURCE_SCHEMA} cal_source_status;
/* Source retirement only, not DAC/FIR-tail or RF completion. Serialize gateway
 * calls; reconcile ambiguous submission instead of retrying automatically.
 * Queue token and origin command sequence are distinct identities. */
cal_command_status cal_source_event_peek_begin(const cal_command_io *,uint32_t sequence);
cal_command_status cal_source_event_pop_begin(const cal_command_io *,uint32_t sequence,uint64_t token);
cal_source_status cal_source_event_decode(const cal_command_result *,const uint32_t words[CAL_CMD_SOURCE_EVENT_PEEK_RESULT_WORDS],cal_source_event_snapshot *);
#endif
