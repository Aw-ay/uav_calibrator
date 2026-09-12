#ifndef CAL_FRAME_DECODE_H
#define CAL_FRAME_DECODE_H
#include <stddef.h>
#include <stdint.h>
#include "generated/calibrator_contract.h"

#define CAL_FRAME_MAX_RECORD_BYTES UINT32_C(131216)

typedef enum {
    CAL_FRAME_OK = 0, CAL_FRAME_NULL, CAL_FRAME_SHORT, CAL_FRAME_LENGTH,
    CAL_FRAME_HEADER, CAL_FRAME_SAMPLES, CAL_FRAME_GRID, CAL_FRAME_RESERVED,
    CAL_FRAME_HEADER_CRC, CAL_FRAME_TRAILER
} cal_frame_status;

typedef struct {
    const uint8_t *record;
    const uint8_t *payload;
    uint32_t record_bytes, payload_bytes, sample_count, quality_flags;
    uint64_t pulse_id, record_sequence, gsc_first;
    uint32_t epoch_id, config_id, sample_stride_ticks, sample_rate_num, sample_rate_den;
    uint16_t format_id;
    uint8_t range_id, channel_mask, stream_group_id, physical_adc_mask, source_role, source_flags;
} cal_frame_view;

typedef struct { int16_t h_i, h_q, v_i, v_q; } cal_iq16;

uint32_t cal_crc32c(const void *data, size_t bytes);
cal_frame_status cal_frame_decode(const void *record, size_t available_bytes,
                                  size_t actual_bd_bytes, cal_frame_view *out);
cal_frame_status cal_frame_sample(const cal_frame_view *frame, uint32_t index, cal_iq16 *out);
const char *cal_frame_status_string(cal_frame_status status);
#endif
