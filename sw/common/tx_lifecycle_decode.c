#include "include/tx_lifecycle_decode.h"
static uint32_t get32(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint64_t get64(const uint8_t *p){return get32(p)|((uint64_t)get32(p+4)<<32);}
cal_tx_lifecycle_status cal_tx_lifecycle_decode(const void *bytes,size_t size,cal_tx_lifecycle_event *out){
 const uint8_t *p=bytes;cal_tx_lifecycle_event e={0};
 if(!p||!out)return CAL_TX_ARGUMENT;
 if(size<TX_LIFECYCLE_BYTES)return CAL_TX_SHORT;
 if(get32(p+TX_LIFECYCLE_TAG_OFFSET)!=TX_LIFECYCLE_TAG)return CAL_TX_SCHEMA;
 e.flags=get32(p+TX_LIFECYCLE_FLAGS_OFFSET);
 if(e.flags&~(TX_LIFECYCLE_DIGITAL_DRAINED|TX_LIFECYCLE_TIME_VALID|TX_LIFECYCLE_SINK_CONFIRMED))return CAL_TX_SCHEMA;
 for(size_t i=TX_LIFECYCLE_RESERVED_OFFSET;i<TX_LIFECYCLE_BYTES;i++)if(p[i])return CAL_TX_RESERVED;
 e.source=get32(p+TX_LIFECYCLE_SOURCE_OFFSET);e.reason=get32(p+TX_LIFECYCLE_REASON_OFFSET);
 e.command_sequence=get32(p+TX_LIFECYCLE_COMMAND_SEQUENCE_OFFSET);e.config_id=get32(p+TX_LIFECYCLE_CONFIG_ID_OFFSET);
 e.token=get64(p+TX_LIFECYCLE_TOKEN_OFFSET);e.accept_gsc=get64(p+TX_LIFECYCLE_ACCEPT_GSC_OFFSET);
 e.drain_gsc=get64(p+TX_LIFECYCLE_DRAIN_GSC_OFFSET);e.retire_gsc=get64(p+TX_LIFECYCLE_RETIRE_GSC_OFFSET);
 if(!(e.flags&TX_LIFECYCLE_DIGITAL_DRAINED)||!e.token||e.source<TX_LIFECYCLE_SOURCE_DDS||e.source>TX_LIFECYCLE_SOURCE_REPLAY||e.reason>TX_LIFECYCLE_REASON_REPLAY_ABORT||(e.reason==TX_LIFECYCLE_REASON_REPLAY_ABORT&&e.source!=TX_LIFECYCLE_SOURCE_REPLAY))return CAL_TX_VALUE;
 if(e.flags&TX_LIFECYCLE_TIME_VALID){if(e.accept_gsc>e.drain_gsc||e.drain_gsc>e.retire_gsc)return CAL_TX_VALUE;}
 else if(e.accept_gsc||e.drain_gsc||e.retire_gsc)return CAL_TX_VALUE;
 *out=e;return CAL_TX_OK;
}
