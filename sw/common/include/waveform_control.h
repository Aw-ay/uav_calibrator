#ifndef CAL_WAVEFORM_CONTROL_H
#define CAL_WAVEFORM_CONTROL_H
#include <stddef.h>
#include "command_control.h"
#include "instrument_control.h"
typedef struct {
 uint64_t start_gsc;
 uint32_t pw_samples,pri_samples,pulse_count;
 uint64_t initial_pinc,chirp_step; /* unsigned 48-bit phase words */
 uint8_t reset_each_pulse;
} cal_dds_command;
/* These functions submit one transaction. Poll the same sequence with
 * cal_command_poll and inspect result.code before submitting another command.
 * OK from begin is submission only, not RF emission or waveform completion.
 * SUBMIT_UNKNOWN must be reconciled; these helpers never retry automatically.
 * DDS start must leave enough lead time for the whole MMIO/CDC transaction.
 * Hardware rejects past timestamps, wrong modes and unavailable RF permission. */
cal_command_status cal_dds_begin(const cal_command_io *,uint32_t sequence,const cal_dds_command *);
/* CRC32C over little-endian 64-bit {VQ,VI,HQ,HI} words, seed/final XOR all ones.
 * samples must point to count valid words; count=0 permits a null pointer. */
uint32_t cal_awg_crc32c(const uint64_t *samples,size_t count);
cal_command_status cal_awg_load_begin(const cal_command_io *,uint32_t sequence,uint32_t length,uint32_t crc32c);
cal_command_status cal_awg_write(const cal_command_io *,uint32_t sequence,uint64_t hv_sample);
/* Requires acquisition stopped, MUTE and drained consumers. BUSY preserves the
 * loaded inactive table. Stop first, poll completion, then retry with a new
 * sequence. RF feedback/dwell and table CRC are never bypassed by this API. */
cal_command_status cal_awg_commit(const cal_command_io *,uint32_t sequence);
cal_command_status cal_awg_play(const cal_command_io *,uint32_t sequence);
#endif
