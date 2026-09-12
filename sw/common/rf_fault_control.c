#include "rf_fault_control.h"
cal_command_status cal_rf_fault_peek_begin(const cal_command_io *io,uint32_t seq){
 return cal_command_begin(io,CAL_CMD_RF_FAULT_PEEK,CAL_CMD_RF_FAULT_PEEK_WORDS,seq,0);
}
cal_command_status cal_rf_fault_pop_begin(const cal_command_io *io,uint32_t seq,uint64_t token){
 uint32_t p[2]={(uint32_t)token,(uint32_t)(token>>32)};
 if(!token)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_RF_FAULT_POP,CAL_CMD_RF_FAULT_POP_WORDS,seq,p);
}
cal_rf_fault_status cal_rf_fault_decode(const cal_command_result *r,const uint32_t p[CAL_CMD_RF_FAULT_PEEK_RESULT_WORDS],cal_rf_fault_snapshot *out){
 cal_rf_fault_snapshot s={0};unsigned i;
 if(!r||!p||!out)return CAL_RF_FAULT_ARGUMENT;
 if(r->code)return CAL_RF_FAULT_COMMAND;
 if(r->words!=CAL_CMD_RF_FAULT_PEEK_RESULT_WORDS||p[0]>CAL_RF_FAULT_DEPTH)return CAL_RF_FAULT_SCHEMA;
 s.count=p[0];s.dropped=p[1];s.token=p[2]|((uint64_t)p[3]<<32);
 if(!s.count){
  for(i=2;i<CAL_CMD_RF_FAULT_PEEK_RESULT_WORDS;i++)if(p[i])return CAL_RF_FAULT_SCHEMA;
  *out=s;return CAL_RF_FAULT_EMPTY;
 }
 if(!s.token||p[4]!=CAL_RF_FAULT_TAG||(p[5]&~(CAL_RF_FAULT_TIME_VALID|CAL_RF_FAULT_CONFIG_VALID))||p[7]>4||p[8]>1023||p[9]>63)return CAL_RF_FAULT_SCHEMA;
 s.flags=p[5];s.config_id=p[6];s.rf_state=p[7];s.normalized_inputs=p[8];s.logical_outputs=p[9];
 s.observation_gsc=p[10]|((uint64_t)p[11]<<32);
 if(!(s.flags&CAL_RF_FAULT_TIME_VALID)&&s.observation_gsc)return CAL_RF_FAULT_SCHEMA;
 if(!(s.flags&CAL_RF_FAULT_CONFIG_VALID)&&s.config_id)return CAL_RF_FAULT_SCHEMA;
 *out=s;return CAL_RF_FAULT_OK;
}
