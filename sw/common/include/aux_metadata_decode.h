#ifndef CAL_AUX_METADATA_DECODE_H
#define CAL_AUX_METADATA_DECODE_H
#include <stdint.h>
#include <stddef.h>
#include "aux_metadata.h"
typedef enum {CAL_AM_OK=0,CAL_AM_ARGUMENT,CAL_AM_SHORT,CAL_AM_SCHEMA,CAL_AM_RESERVED,CAL_AM_VALUE} cal_aux_metadata_status;
typedef struct {
 uint32_t metadata_id;
 uint32_t epoch_id;
 uint64_t capture_id;
 uint64_t owner_epoch;
 uint64_t generation;
 uint64_t tx_token;
 uint64_t start_seq;
 uint64_t start_gsc;
 uint32_t source_epoch;
 uint32_t h_calibration_id;
 uint32_t v_calibration_id;
 uint32_t config_id;
 uint32_t fir_id;
 uint32_t sample_count;
 uint8_t source_role;
 uint8_t bank;
 uint8_t status;
} cal_aux_metadata;
cal_aux_metadata_status cal_aux_metadata_decode(const void *bytes,size_t size,cal_aux_metadata *out);
#endif
