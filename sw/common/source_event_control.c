#include "source_event_control.h"
cal_command_status cal_source_event_peek_begin(const cal_command_io *io,uint32_t seq){
 return cal_command_begin(io,CAL_CMD_SOURCE_EVENT_PEEK,CAL_CMD_SOURCE_EVENT_PEEK_WORDS,seq,0);
}
cal_command_status cal_source_event_pop_begin(const cal_command_io *io,uint32_t seq,uint64_t token){
 uint32_t p[2]={(uint32_t)token,(uint32_t)(token>>32)};
 if(!token)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_SOURCE_EVENT_POP,CAL_CMD_SOURCE_EVENT_POP_WORDS,seq,p);
}
cal_source_status cal_source_event_decode(const cal_command_result *r,const uint32_t p[CAL_CMD_SOURCE_EVENT_PEEK_RESULT_WORDS],cal_source_event_snapshot *out){
 cal_source_event_snapshot s={0};unsigned i;
 if(!r||!p||!out)return CAL_SOURCE_ARGUMENT;
 if(r->code)return CAL_SOURCE_COMMAND;
 if(r->words!=CAL_CMD_SOURCE_EVENT_PEEK_RESULT_WORDS||p[0]>CAL_SOURCE_EVENT_DEPTH)return CAL_SOURCE_SCHEMA;
 s.count=p[0];s.dropped=p[1];s.token=p[2]|((uint64_t)p[3]<<32);
 if(!s.count){
  for(i=2;i<CAL_CMD_SOURCE_EVENT_PEEK_RESULT_WORDS;i++)if(p[i])return CAL_SOURCE_SCHEMA;
  *out=s;return CAL_SOURCE_EMPTY;
 }
 if(!s.token||p[4]!=CAL_SOURCE_EVENT_TAG||(p[5]!=CAL_SOURCE_DDS&&p[5]!=CAL_SOURCE_AWG)||p[6]>CAL_SOURCE_REASON_MUTE||(p[9]&~CAL_SOURCE_EVENT_TIME_VALID))return CAL_SOURCE_SCHEMA;
 s.source=p[5];s.reason=p[6];s.command_sequence=p[7];s.config_id=p[8];s.flags=p[9];
 s.accept_gsc=p[10]|((uint64_t)p[11]<<32);s.drain_gsc=p[12]|((uint64_t)p[13]<<32);
 if(s.flags){if(s.drain_gsc<s.accept_gsc)return CAL_SOURCE_SCHEMA;}
 else if(s.accept_gsc||s.drain_gsc)return CAL_SOURCE_SCHEMA;
 *out=s;return CAL_SOURCE_OK;
}
