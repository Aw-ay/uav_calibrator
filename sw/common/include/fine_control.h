#ifndef CAL_FINE_CONTROL_H
#define CAL_FINE_CONTROL_H
#include "command_control.h"
#include "instrument_control.h"
#include "fine_pdw_layout.h"
typedef struct {
 uint32_t flags,config_id;uint64_t pulse_id,owner_epoch,generation,gsc_first;
 uint8_t range_id,bank_id,selected,valid_mask;
 uint32_t rise_q16[2],fall_q16[2],peak_power[2],mean_power[2],snr_q16[2];
 int32_t frequency_hz[2],hv_phase_q31;int64_t chirp_hz_per_s[2];
 uint16_t edge_quality[2];uint8_t spectral_quality[3];
} cal_fine_pdw;
typedef struct {uint32_t count,dropped;uint64_t token;cal_fine_pdw pdw;} cal_fine_snapshot;
typedef enum {CAL_FINE_OK=0,CAL_FINE_EMPTY,CAL_FINE_ARGUMENT,CAL_FINE_COMMAND,CAL_FINE_SCHEMA} cal_fine_status;
/* Serialize all gateway users. PEEK is nondestructive; process before exact-token
 * POP. Reconcile ambiguous submissions with command_poll, never blindly retry.
 * Capture soft reset preserves records; coordinated cold reset flushes them. */
cal_command_status cal_fine_peek_begin(const cal_command_io *,uint32_t sequence);
cal_command_status cal_fine_pop_begin(const cal_command_io *,uint32_t sequence,uint64_t token);
cal_fine_status cal_fine_snapshot_decode(const cal_command_result *,const uint32_t words[36],cal_fine_snapshot *);
#endif
