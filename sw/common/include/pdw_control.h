#ifndef CAL_PDW_CONTROL_H
#define CAL_PDW_CONTROL_H
#include "command_control.h"
#include "instrument_control.h"
#include "../event_control.h"
typedef struct {uint32_t count,dropped;uint64_t token;cal_event event;} cal_pdw_snapshot;
typedef enum {CAL_PDW_OK=0,CAL_PDW_EMPTY,CAL_PDW_ARGUMENT,CAL_PDW_COMMAND,CAL_PDW_SCHEMA} cal_pdw_status;
/* Serialize begin/poll using command_control. A gateway sequence identifies the
 * command; a PDW token identifies the retained queue head. Do not confuse them.
 * PEEK is nondestructive. Decode and consume the event before POP with its token.
 * A failed/ambiguous submission must be reconciled, never automatically retried.
 * Capture soft reset preserves historical PDW; hard reset flushes it. */
cal_command_status cal_pdw_peek_begin(const cal_command_io *,uint32_t sequence);
cal_command_status cal_pdw_pop_begin(const cal_command_io *,uint32_t sequence,uint64_t token);
cal_pdw_status cal_pdw_snapshot_decode(const cal_command_result *,const uint32_t words[CAL_CMD_PDW_PEEK_RESULT_WORDS],cal_pdw_snapshot *);
#endif
