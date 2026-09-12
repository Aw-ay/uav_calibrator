#include "pdw_control.h"
cal_command_status cal_pdw_peek_begin(const cal_command_io *io,uint32_t seq){
 return cal_command_begin(io,CAL_CMD_PDW_PEEK,CAL_CMD_PDW_PEEK_WORDS,seq,0);
}
cal_command_status cal_pdw_pop_begin(const cal_command_io *io,uint32_t seq,uint64_t token){
 uint32_t p[2]={(uint32_t)token,(uint32_t)(token>>32)};
 if(!token)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_PDW_POP,CAL_CMD_PDW_POP_WORDS,seq,p);
}
cal_pdw_status cal_pdw_snapshot_decode(const cal_command_result *r,const uint32_t p[CAL_CMD_PDW_PEEK_RESULT_WORDS],cal_pdw_snapshot *out){
 cal_pdw_snapshot s={0};uint8_t bytes[64];unsigned i,j;
 if(!r||!p||!out)return CAL_PDW_ARGUMENT;
 if(r->code)return CAL_PDW_COMMAND;
 if(r->words!=CAL_CMD_PDW_PEEK_RESULT_WORDS||p[0]>CAL_PDW_QUEUE_DEPTH)return CAL_PDW_SCHEMA;
 s.count=p[0];s.dropped=p[1];s.token=p[2]|((uint64_t)p[3]<<32);
 if(!s.count){
  for(i=2;i<CAL_CMD_PDW_PEEK_RESULT_WORDS;i++)if(p[i])return CAL_PDW_SCHEMA;
  *out=s;return CAL_PDW_EMPTY;
 }
 if(!s.token)return CAL_PDW_SCHEMA;
 for(i=0;i<16;i++)for(j=0;j<4;j++)bytes[i*4+j]=(uint8_t)(p[4+i]>>(8*j));
 if(cal_event_decode(bytes,sizeof bytes,&s.event)!=CAL_EVENT_OK)return CAL_PDW_SCHEMA;
 *out=s;return CAL_PDW_OK;
}
