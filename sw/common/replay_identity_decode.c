#include "include/replay_identity_decode.h"
static uint32_t get32(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint64_t get64(const uint8_t *p){return get32(p)|((uint64_t)get32(p+4)<<32);}
cal_replay_identity_status cal_replay_identity_decode(const void *bytes,size_t size,cal_replay_identity *out){
 const uint8_t *p=bytes;cal_replay_identity e={0};
 if(!p||!out)return CAL_RI_ARGUMENT;
 if(size<REPLAY_IDENTITY_BYTES)return CAL_RI_SHORT;
 if(get32(p+REPLAY_IDENTITY_TAG_OFFSET)!=REPLAY_IDENTITY_TAG)return CAL_RI_SCHEMA;
 if(get32(p+REPLAY_IDENTITY_RESERVED_OFFSET))return CAL_RI_RESERVED;
 e.token=get64(p+REPLAY_IDENTITY_TOKEN_OFFSET);e.task_id=get64(p+REPLAY_IDENTITY_TASK_ID_OFFSET);
 e.pulse_id=get64(p+REPLAY_IDENTITY_PULSE_ID_OFFSET);e.owner_epoch=get64(p+REPLAY_IDENTITY_OWNER_EPOCH_OFFSET);
 e.generation=get64(p+REPLAY_IDENTITY_GENERATION_OFFSET);e.config_id=get32(p+REPLAY_IDENTITY_CONFIG_ID_OFFSET);
 e.fir_id=get32(p+REPLAY_IDENTITY_FIR_ID_OFFSET);e.source_epoch=get32(p+REPLAY_IDENTITY_SOURCE_EPOCH_OFFSET);
 e.group=(uint16_t)(p[REPLAY_IDENTITY_GROUP_OFFSET]|((uint16_t)p[REPLAY_IDENTITY_GROUP_OFFSET+1]<<8));
 e.bank=(uint16_t)(p[REPLAY_IDENTITY_BANK_OFFSET]|((uint16_t)p[REPLAY_IDENTITY_BANK_OFFSET+1]<<8));
 if(!e.token||e.group<1||e.group>4||e.bank>3)return CAL_RI_VALUE;
 *out=e;return CAL_RI_OK;
}
