#include "waveform_control.h"
cal_command_status cal_dds_begin(const cal_command_io *io,uint32_t seq,const cal_dds_command *d){
 uint32_t p[CAL_CMD_DDS_WORDS];uint64_t duration;
 if(!d||!d->pw_samples||d->pri_samples<d->pw_samples||!d->pulse_count||
    (d->start_gsc&3u)||(d->initial_pinc>>48)||(d->chirp_step>>48)||d->reset_each_pulse>1)
  return CAL_CMD_ARGUMENT;
 duration=(uint64_t)d->pri_samples*d->pulse_count;
 if(duration>(UINT64_MAX-d->start_gsc)/4u)return CAL_CMD_ARGUMENT;
 p[0]=(uint32_t)d->start_gsc;p[1]=(uint32_t)(d->start_gsc>>32);
 p[2]=d->pw_samples;p[3]=d->pri_samples;p[4]=d->pulse_count;
 p[5]=(uint32_t)d->initial_pinc;
 p[6]=(uint32_t)(d->initial_pinc>>32)|((uint32_t)d->chirp_step<<16);
 p[7]=(uint32_t)(d->chirp_step>>16);p[8]=d->reset_each_pulse;
 return cal_command_begin(io,CAL_CMD_DDS,CAL_CMD_DDS_WORDS,seq,p);
}
uint32_t cal_awg_crc32c(const uint64_t *samples,size_t count){
 uint32_t crc=UINT32_MAX;size_t n;unsigned b;
 for(n=0;n<count;n++){
  uint64_t word=samples[n];
  for(b=0;b<64;b++){crc=(crc>>1)^(((crc^(uint32_t)word)&1u)?0x82f63b78u:0u);word>>=1;}
 }
 return ~crc;
}
static cal_command_status awg(const cal_command_io *io,uint32_t seq,uint32_t op,uint32_t len,uint32_t crc,uint64_t data){
 uint32_t p[CAL_CMD_AWG_LOAD_WORDS]={op,len,crc,(uint32_t)data,(uint32_t)(data>>32)};
 return cal_command_begin(io,CAL_CMD_AWG_LOAD,CAL_CMD_AWG_LOAD_WORDS,seq,p);
}
cal_command_status cal_awg_load_begin(const cal_command_io *io,uint32_t seq,uint32_t length,uint32_t crc){
 if(!length)return CAL_CMD_ARGUMENT;
 return awg(io,seq,0,length,crc,0);
}
cal_command_status cal_awg_write(const cal_command_io *io,uint32_t seq,uint64_t data){return awg(io,seq,1,0,0,data);}
cal_command_status cal_awg_commit(const cal_command_io *io,uint32_t seq){return awg(io,seq,2,0,0,0);}
cal_command_status cal_awg_play(const cal_command_io *io,uint32_t seq){return cal_command_begin(io,CAL_CMD_AWG_PLAY,CAL_CMD_AWG_PLAY_WORDS,seq,0);}
