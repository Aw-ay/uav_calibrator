#ifndef CAL_CALIBRATION_TABLE_H
#define CAL_CALIBRATION_TABLE_H
#include <stdint.h>
#include <stddef.h>
#include "include/calibration_table_format.h"
typedef enum { CAL_TABLE_OK=0,CAL_TABLE_ARGUMENT,CAL_TABLE_SIZE,CAL_TABLE_SCHEMA,CAL_TABLE_RESERVED,CAL_TABLE_CRC,CAL_TABLE_CONTEXT,CAL_TABLE_EXPIRED,CAL_TABLE_DISABLED,CAL_TABLE_UNBOUND } cal_table_status;
typedef struct {
 uint32_t cal_id;uint64_t generation;uint32_t direction,logical_channel,reference_plane_id;
 uint64_t now_gsc,binding_id;int production_binding_valid;
} cal_table_expect;
typedef struct {
 int32_t gain_i,gain_q;int16_t dc_i,dc_q;
 uint32_t cal_id,direction,logical_channel,reference_plane_id;
 uint64_t generation,valid_from,valid_until,binding_id;
 int logical_valid,calibration_valid;
} cal_table_view;
cal_table_status cal_table_validate(const void *bytes,size_t size,const cal_table_expect *expected,cal_table_view *out);
#endif
