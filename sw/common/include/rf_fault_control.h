#ifndef CAL_RF_FAULT_CONTROL_H
#define CAL_RF_FAULT_CONTROL_H
#include "command_control.h"
#include "instrument_control.h"
typedef struct {
 uint32_t count,dropped;uint64_t token;
 uint32_t flags,config_id,rf_state,normalized_inputs,logical_outputs;
 uint64_t observation_gsc;
} cal_rf_fault_snapshot;
typedef enum {CAL_RF_FAULT_OK=0,CAL_RF_FAULT_EMPTY,CAL_RF_FAULT_ARGUMENT,CAL_RF_FAULT_COMMAND,CAL_RF_FAULT_SCHEMA} cal_rf_fault_status;
/* Observed latch assertion context, not a causal diagnostic or RF timestamp.
 * Serialize command use; do not retry ambiguous submissions automatically.
 * POP removes history only and never clears the interlock latch. */
cal_command_status cal_rf_fault_peek_begin(const cal_command_io *,uint32_t sequence);
cal_command_status cal_rf_fault_pop_begin(const cal_command_io *,uint32_t sequence,uint64_t token);
cal_rf_fault_status cal_rf_fault_decode(const cal_command_result *,const uint32_t words[CAL_CMD_RF_FAULT_PEEK_RESULT_WORDS],cal_rf_fault_snapshot *);
#endif
