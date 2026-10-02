#include "fine_control.h"
#include <string.h>
static uint64_t u64(const uint32_t *p){return p[0]|((uint64_t)p[1]<<32);}
static int32_t i32(uint32_t v){int32_t r;memcpy(&r,&v,4);return r;}
static int64_t i64(const uint32_t *p){uint64_t v=u64(p);int64_t r;memcpy(&r,&v,8);return r;}
cal_command_status cal_fine_peek_begin(const cal_command_io *io,uint32_t sequence){return cal_command_begin(io,CAL_CMD_FINE_PDW_PEEK,0,sequence,0);}
cal_command_status cal_fine_pop_begin(const cal_command_io *io,uint32_t sequence,uint64_t token){
 uint32_t words[2]={(uint32_t)token,(uint32_t)(token>>32)};
 if(!token)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_FINE_PDW_POP,2,sequence,words);
}
cal_fine_status cal_fine_snapshot_decode(const cal_command_result *r,const uint32_t words[36],cal_fine_snapshot *out){
 cal_fine_snapshot s={0};const uint32_t *p;unsigned n;
 if(!r||!words||!out)return CAL_FINE_ARGUMENT;
 if(r->code)return CAL_FINE_COMMAND;
 if(r->words!=36||words[0]>64)return CAL_FINE_SCHEMA;
 s.count=words[0];s.dropped=words[1];s.token=u64(words+2);
 if(!s.count){for(n=2;n<36;n++)if(words[n])return CAL_FINE_SCHEMA;*out=s;return CAL_FINE_EMPTY;}
 p=words+4;
 if(!s.token||p[0]!=CAL_FINE_PDW_TAG||p[31]||p[1]&~3u||p[30]&0xff000000u)return CAL_FINE_SCHEMA;
 s.pdw.flags=p[1];s.pdw.pulse_id=u64(p+2);s.pdw.owner_epoch=u64(p+4);s.pdw.generation=u64(p+6);s.pdw.config_id=p[8];
 s.pdw.range_id=(uint8_t)p[9];s.pdw.bank_id=(uint8_t)(p[9]>>8);s.pdw.selected=(uint8_t)(p[9]>>16);s.pdw.valid_mask=(uint8_t)(p[9]>>24);
 if(s.pdw.range_id<1||s.pdw.range_id>3||s.pdw.bank_id>3||s.pdw.selected>1||(s.pdw.valid_mask&~31u))return CAL_FINE_SCHEMA;
 s.pdw.gsc_first=u64(p+10);
 for(n=0;n<2;n++){
  s.pdw.rise_q16[n]=p[12+2*n];s.pdw.fall_q16[n]=p[13+2*n];s.pdw.peak_power[n]=p[16+n];s.pdw.mean_power[n]=p[18+n];
  s.pdw.frequency_hz[n]=i32(p[20+n]);s.pdw.chirp_hz_per_s[n]=i64(p+22+2*n);s.pdw.snr_q16[n]=p[27+n];s.pdw.edge_quality[n]=(uint16_t)(p[29]>>(n*16));
 }
 s.pdw.hv_phase_q31=i32(p[26]);for(n=0;n<3;n++)s.pdw.spectral_quality[n]=(uint8_t)(p[30]>>(8*n));
 *out=s;return CAL_FINE_OK;
}
