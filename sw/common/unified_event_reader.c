#include "include/unified_event_reader.h"
_Static_assert(EVENT_BYTES==FAULT_EVENT_BYTES,"Unified records must have equal size");
static int valid(const cal_event_io *io){return io&&io->read32&&io->write32;}
void cal_unified_event_init(cal_unified_event_reader *r){
 if(r){cal_unified_event_reader empty={0};*r=empty;}
}
cal_unified_event_status cal_unified_event_fetch(const cal_event_io *io,cal_unified_event_reader *r){
 cal_unified_event_reader next={0};uint32_t count,word,tag=0;
 cal_unified_event_status result=CAL_UE_OK;
 if(!valid(io)||!r)return CAL_UE_ARGUMENT;
 if(r->state==CAL_UE_UNCERTAIN)return CAL_UE_POP_UNCERTAIN;
 if(r->state!=CAL_UE_IDLE)return CAL_UE_BUSY;
 if(io->read32(io->context,REG_EVENT_COUNT,&count))return CAL_UE_IO_COUNT;
 if(!count)return CAL_UE_EMPTY;
 if(io->write32(io->context,REG_EVENT_LATCH,1))return CAL_UE_IO_LATCH;
 for(unsigned i=0;i<EVENT_BYTES/4;i++){
  if(io->read32(io->context,REG_EVENT_WORD_0+i*(REG_EVENT_WORD_1-REG_EVENT_WORD_0),&word))return CAL_UE_IO_READ;
  for(unsigned j=0;j<4;j++)next.raw[i*4+j]=(uint8_t)(word>>(8*j));
 }
 for(unsigned j=0;j<4;j++)tag|=(uint32_t)next.raw[j]<<(8*j);
 next.state=CAL_UE_SNAPSHOT;
 if(tag==EVENT_CAPTURE_TAG){
  next.kind=CAL_UE_CAPTURE;next.decode_status=cal_event_decode(next.raw,sizeof next.raw,&next.decoded.capture);
  if(next.decode_status!=CAL_EVENT_OK)result=CAL_UE_INVALID_RECORD;
 }else if(tag==FAULT_EVENT_TAG){
  next.kind=CAL_UE_FAULT;next.decode_status=cal_fault_event_decode(next.raw,sizeof next.raw,&next.decoded.fault);
  if(next.decode_status!=CAL_FE_OK)result=CAL_UE_INVALID_RECORD;
 }else result=CAL_UE_UNSUPPORTED;
 *r=next;return result;
}
cal_unified_event_status cal_unified_event_pop(const cal_event_io *io,cal_unified_event_reader *r){
 if(!valid(io)||!r)return CAL_UE_ARGUMENT;
 if(r->state==CAL_UE_UNCERTAIN)return CAL_UE_POP_UNCERTAIN;
 if(r->state!=CAL_UE_SNAPSHOT)return CAL_UE_NOT_LATCHED;
 if(io->write32(io->context,REG_EVENT_POP,1)){r->state=CAL_UE_UNCERTAIN;return CAL_UE_POP_UNCERTAIN;}
 cal_unified_event_init(r);return CAL_UE_OK;
}
