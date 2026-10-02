#include "include/aux_metadata_decode.h"
static uint64_t le(const uint8_t *p,unsigned n){uint64_t v=0;for(unsigned i=0;i<n;i++)v|=(uint64_t)p[i]<<(8*i);return v;}
cal_aux_metadata_status cal_aux_metadata_decode(const void *bytes,size_t size,cal_aux_metadata *out){
 const uint8_t *p=bytes;cal_aux_metadata e={0};
 if(!p||!out)return CAL_AM_ARGUMENT;
 if(size<AUX_META_BYTES)return CAL_AM_SHORT;
 if(le(p+AUX_META_MAGIC_OFFSET,4)!=AUX_META_MAGIC||le(p+AUX_META_VERSION_OFFSET,2)!=AUX_META_VERSION||le(p+AUX_META_BYTES_OFFSET,2)!=AUX_META_BYTES)return CAL_AM_SCHEMA;
 if(p[AUX_META_RESERVED0_OFFSET]||le(p+AUX_META_RESERVED1_OFFSET,4))return CAL_AM_RESERVED;
 e.metadata_id=(uint32_t)le(p+AUX_META_METADATA_ID_OFFSET,4);
 e.epoch_id=(uint32_t)le(p+AUX_META_EPOCH_ID_OFFSET,4);
 e.capture_id=(uint64_t)le(p+AUX_META_CAPTURE_ID_OFFSET,8);
 e.owner_epoch=(uint64_t)le(p+AUX_META_OWNER_EPOCH_OFFSET,8);
 e.generation=(uint64_t)le(p+AUX_META_GENERATION_OFFSET,8);
 e.tx_token=(uint64_t)le(p+AUX_META_TX_TOKEN_OFFSET,8);
 e.start_seq=(uint64_t)le(p+AUX_META_START_SEQ_OFFSET,8);
 e.start_gsc=(uint64_t)le(p+AUX_META_START_GSC_OFFSET,8);
 e.source_epoch=(uint32_t)le(p+AUX_META_SOURCE_EPOCH_OFFSET,4);
 e.h_calibration_id=(uint32_t)le(p+AUX_META_H_CALIBRATION_ID_OFFSET,4);
 e.v_calibration_id=(uint32_t)le(p+AUX_META_V_CALIBRATION_ID_OFFSET,4);
 e.config_id=(uint32_t)le(p+AUX_META_CONFIG_ID_OFFSET,4);
 e.fir_id=(uint32_t)le(p+AUX_META_FIR_ID_OFFSET,4);
 e.sample_count=(uint32_t)le(p+AUX_META_SAMPLE_COUNT_OFFSET,4);
 e.source_role=(uint8_t)le(p+AUX_META_SOURCE_ROLE_OFFSET,1);
 e.bank=(uint8_t)le(p+AUX_META_BANK_OFFSET,1);
 e.status=(uint8_t)le(p+AUX_META_STATUS_OFFSET,1);

 if(!e.metadata_id||!e.capture_id||!e.sample_count||e.sample_count>16384||e.bank>3||(e.source_role!=2&&e.source_role!=3)||(e.status&0xe0))return CAL_AM_VALUE;
 *out=e;return CAL_AM_OK;
}
