#include "fault_event_decode.h"
static uint32_t get32(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
cal_fault_event_status cal_fault_event_decode(const void *data,size_t size,cal_fault_event *out){
 const uint8_t *p=data;cal_fault_event e;unsigned i;
 if(!p||!out)return CAL_FE_ARGUMENT;
 if(size<FAULT_EVENT_BYTES)return CAL_FE_SHORT;
 if(get32(p+FAULT_EVENT_TAG_OFFSET)!=FAULT_EVENT_TAG||get32(p+FAULT_EVENT_SNAPSHOT_TAG_OFFSET)!=CAL_RF_FAULT_TAG)return CAL_FE_SCHEMA;
 e.flags=get32(p+FAULT_EVENT_FLAGS_OFFSET);e.occurrences=get32(p+FAULT_EVENT_OCCURRENCES_OFFSET);
 e.snapshot_flags=get32(p+FAULT_EVENT_SNAPSHOT_FLAGS_OFFSET);
 if((e.flags&~FAULT_EVENT_COUNT_SATURATED)||(e.snapshot_flags&~(CAL_RF_FAULT_TIME_VALID|CAL_RF_FAULT_CONFIG_VALID)))return CAL_FE_SCHEMA;
 if(get32(p+FAULT_EVENT_RESERVED_HEADER_OFFSET))return CAL_FE_RESERVED;
 for(i=FAULT_EVENT_RESERVED_TAIL_OFFSET;i<FAULT_EVENT_BYTES;i++)if(p[i])return CAL_FE_RESERVED;
 if(!e.occurrences||((e.flags&FAULT_EVENT_COUNT_SATURATED)&&e.occurrences!=UINT32_MAX))return CAL_FE_VALUE;
 e.config_id=get32(p+FAULT_EVENT_CONFIG_ID_OFFSET);e.rf_state=get32(p+FAULT_EVENT_RF_STATE_OFFSET);
 e.normalized_inputs=get32(p+FAULT_EVENT_NORMALIZED_INPUTS_OFFSET);e.logical_outputs=get32(p+FAULT_EVENT_LOGICAL_OUTPUTS_OFFSET);
 e.observation_gsc=get32(p+FAULT_EVENT_OBSERVATION_GSC_OFFSET)|((uint64_t)get32(p+FAULT_EVENT_OBSERVATION_GSC_OFFSET+4)<<32);
 if(e.rf_state>4||e.normalized_inputs>1023||e.logical_outputs>63||(!(e.snapshot_flags&CAL_RF_FAULT_TIME_VALID)&&e.observation_gsc)||(!(e.snapshot_flags&CAL_RF_FAULT_CONFIG_VALID)&&e.config_id))return CAL_FE_VALUE;
 *out=e;return CAL_FE_OK;
}
