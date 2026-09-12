#include "event_control.h"
static uint32_t get32(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint64_t get64(const uint8_t *p){return get32(p)|((uint64_t)get32(p+4)<<32);}
cal_event_status cal_event_decode(const void *bytes,size_t size,cal_event *out){
 const uint8_t *p=(const uint8_t *)bytes;cal_event e;size_t i;
 const uint32_t known=EVENT_TOA_VALID|EVENT_WIDTH_VALID|EVENT_PEAK_VALID|EVENT_ENERGY_VALID|EVENT_SELECTED_VALID;
 if(!p||!out)return CAL_EVENT_ARGUMENT;
 if(size<EVENT_BYTES)return CAL_EVENT_SHORT;
 if(get32(p+EVENT_TAG_OFFSET)!=EVENT_CAPTURE_TAG)return CAL_EVENT_SCHEMA;
 e.flags=get32(p+EVENT_FLAGS_OFFSET);
 if(e.flags&~known)return CAL_EVENT_SCHEMA;
 for(i=EVENT_RESERVED_OFFSET;i<EVENT_BYTES;i++)if(p[i])return CAL_EVENT_RESERVED;
 e.pulse_id=get64(p+EVENT_PULSE_ID_OFFSET);e.owner_epoch=get64(p+EVENT_OWNER_EPOCH_OFFSET);
 e.config_id=get32(p+EVENT_CONFIG_ID_OFFSET);e.toa_gsc=get64(p+EVENT_TOA_GSC_OFFSET);
 e.width_ticks=get32(p+EVENT_WIDTH_TICKS_OFFSET);e.peak_power=get32(p+EVENT_PEAK_POWER_OFFSET);
 e.energy_sum=get64(p+EVENT_ENERGY_SUM_OFFSET);e.selected_range=get32(p+EVENT_SELECTED_RANGE_OFFSET);
 if((!(e.flags&EVENT_TOA_VALID)&&e.toa_gsc)||(!(e.flags&EVENT_WIDTH_VALID)&&e.width_ticks)||
    (!(e.flags&EVENT_PEAK_VALID)&&e.peak_power)||(!(e.flags&EVENT_ENERGY_VALID)&&e.energy_sum)||
    ((e.flags&EVENT_SELECTED_VALID)?(e.selected_range<1||e.selected_range>3):(e.selected_range!=UINT32_MAX)))return CAL_EVENT_VALUE;
 *out=e;return CAL_EVENT_OK;
}
cal_event_status cal_event_read_next(const cal_event_io *io,cal_event *out){
 uint8_t bytes[EVENT_BYTES];uint32_t count,word;unsigned i,j;cal_event parsed;cal_event_status status;
 if(!io||!io->read32||!io->write32||!out)return CAL_EVENT_ARGUMENT;
 if(io->read32(io->context,REG_EVENT_COUNT,&count))return CAL_EVENT_IO_READ;
 if(!count)return CAL_EVENT_EMPTY;
 if(io->write32(io->context,REG_EVENT_LATCH,1))return CAL_EVENT_IO_LATCH;
 for(i=0;i<EVENT_BYTES/4;i++){
  if(io->read32(io->context,REG_EVENT_WORD_0+i*(REG_EVENT_WORD_1-REG_EVENT_WORD_0),&word))return CAL_EVENT_IO_READ;
  for(j=0;j<4;j++)bytes[i*4+j]=(uint8_t)(word>>(j*8));
 }
 status=cal_event_decode(bytes,sizeof bytes,&parsed);
 if(status!=CAL_EVENT_OK)return status;
 if(io->write32(io->context,REG_EVENT_POP,1))return CAL_EVENT_IO_POP;
 *out=parsed;return CAL_EVENT_OK;
}
