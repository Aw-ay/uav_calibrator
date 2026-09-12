#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "event_control.h"
#include "calibration_table.h"
#include "frame_decode.h"
static uint8_t event[EVENT_BYTES];static int fail_word=-1,pops,latches,reads,fail_count,fail_latch,fail_pop,empty;
static uint32_t le32(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static void put(uint8_t *p,uint64_t v,unsigned n){unsigned i;for(i=0;i<n;i++)p[i]=(uint8_t)(v>>(8*i));}
static int rd(void *ctx,uint32_t off,uint32_t *v){(void)ctx;if(off==REG_EVENT_COUNT){if(fail_count)return -1;*v=empty?0:1;return 0;}assert(off>=REG_EVENT_WORD_0&&off<=REG_EVENT_WORD_15);{int i=(int)((off-REG_EVENT_WORD_0)/4);reads++;if(i==fail_word)return -1;*v=le32(event+i*4);return 0;}}
static int wr(void *ctx,uint32_t off,uint32_t v){(void)ctx;assert(v==1);if(off==REG_EVENT_LATCH){if(fail_latch)return -1;latches++;}else {assert(off==REG_EVENT_POP);pops++;if(fail_pop)return -1;}return 0;}
static void bits(uint8_t *p,unsigned bit,unsigned width,int32_t value){unsigned i;for(i=0;i<width;i++){unsigned b=bit+i;uint8_t mask=(uint8_t)(1u<<(b%8));p[b/8]=(uint8_t)((p[b/8]&~mask)|(((uint32_t)value>>i&1u)<<(b%8)));}}
static void seal(uint8_t *t){put(t+CAL_TABLE_PAYLOAD_CRC32C_OFFSET,cal_crc32c(t+CAL_TABLE_PAYLOAD_OFFSET,CAL_TABLE_PAYLOAD_BYTES),4);put(t+CAL_TABLE_RECORD_CRC32C_OFFSET,0,4);put(t+CAL_TABLE_RECORD_CRC32C_OFFSET,cal_crc32c(t,CAL_TABLE_BYTES),4);}
int main(void){
 cal_event e;cal_event_io io={0,rd,wr};int i;uint8_t table[CAL_TABLE_BYTES]={0};cal_table_view v;
 cal_table_expect expected={1,2,0,3,4,100,9,0};
 put(event+EVENT_TAG_OFFSET,EVENT_CAPTURE_TAG,4);put(event+EVENT_FLAGS_OFFSET,EVENT_TOA_VALID|EVENT_SELECTED_VALID,4);put(event+EVENT_PULSE_ID_OFFSET,UINT64_C(0x123456789abcdef0),8);put(event+EVENT_TOA_GSC_OFFSET,1234,8);put(event+EVENT_SELECTED_RANGE_OFFSET,2,4);
 assert(cal_event_decode(event,sizeof event,&e)==CAL_EVENT_OK&&e.pulse_id==UINT64_C(0x123456789abcdef0)&&e.toa_gsc==1234);
 for(i=0;i<16;i++){fail_word=i;pops=0;assert(cal_event_read_next(&io,&e)==CAL_EVENT_IO_READ&&pops==0);}fail_word=-1;reads=pops=latches=0;
 assert(cal_event_read_next(&io,&e)==CAL_EVENT_OK&&reads==16&&latches==1&&pops==1);
 pops=latches=0;empty=1;assert(cal_event_read_next(&io,&e)==CAL_EVENT_EMPTY&&pops==0&&latches==0);empty=0;
 fail_count=1;assert(cal_event_read_next(&io,&e)==CAL_EVENT_IO_READ&&pops==0);fail_count=0;
 fail_latch=1;assert(cal_event_read_next(&io,&e)==CAL_EVENT_IO_LATCH&&pops==0);fail_latch=0;
 fail_pop=1;e.pulse_id=99;assert(cal_event_read_next(&io,&e)==CAL_EVENT_IO_POP&&e.pulse_id==99);fail_pop=0;
 assert(cal_event_decode(event,EVENT_BYTES-1,&e)==CAL_EVENT_SHORT);
 event[EVENT_RESERVED_OFFSET]=1;assert(cal_event_decode(event,sizeof event,&e)==CAL_EVENT_RESERVED);event[EVENT_RESERVED_OFFSET]=0;
 put(event+EVENT_TAG_OFFSET,9,4);pops=0;assert(cal_event_read_next(&io,&e)==CAL_EVENT_SCHEMA&&pops==0);
 put(table+CAL_TABLE_MAGIC_OFFSET,CAL_TABLE_MAGIC,4);put(table+CAL_TABLE_FORMAT_VERSION_OFFSET,CAL_TABLE_VERSION,4);put(table+CAL_TABLE_CAL_ID_OFFSET,1,4);put(table+CAL_TABLE_GENERATION_OFFSET,2,8);put(table+CAL_TABLE_LOGICAL_CHANNEL_OFFSET,3,4);put(table+CAL_TABLE_REFERENCE_PLANE_ID_OFFSET,4,4);put(table+CAL_TABLE_VALID_FROM_OFFSET,90,8);put(table+CAL_TABLE_VALID_UNTIL_OFFSET,110,8);put(table+CAL_TABLE_BINDING_ID_OFFSET,9,8);put(table+CAL_TABLE_VALID_OFFSET,1,4);put(table+CAL_TABLE_PAYLOAD_OFFSET,65536,3);seal(table);
 assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_UNBOUND&&v.logical_valid&&!v.calibration_valid&&v.gain_i==65536);
 expected.production_binding_valid=1;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_OK&&v.calibration_valid);
 expected.now_gsc=110;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_EXPIRED&&!v.calibration_valid);expected.now_gsc=90;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_OK);
 expected.generation=3;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_CONTEXT);expected.generation=2;
 table[CAL_TABLE_PAYLOAD_OFFSET]^=1;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_CRC);table[CAL_TABLE_PAYLOAD_OFFSET]^=1;
 put(table+CAL_TABLE_FORMAT_VERSION_OFFSET,2,4);seal(table);assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_SCHEMA);
 put(table+CAL_TABLE_FORMAT_VERSION_OFFSET,CAL_TABLE_VERSION,4);seal(table);
 table[CAL_TABLE_CAL_ID_OFFSET]^=1;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_CRC);table[CAL_TABLE_CAL_ID_OFFSET]^=1;
 expected.binding_id=10;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_CONTEXT&&!v.calibration_valid);expected.binding_id=9;
 expected.now_gsc=89;assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_EXPIRED);expected.now_gsc=100;
 put(table+CAL_TABLE_VALID_OFFSET,0,4);seal(table);assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_DISABLED);put(table+CAL_TABLE_VALID_OFFSET,1,4);
 bits(table+CAL_TABLE_PAYLOAD_OFFSET,CAL_PAYLOAD_GAIN_I_BIT,CAL_PAYLOAD_GAIN_I_WIDTH,-131072);
 bits(table+CAL_TABLE_PAYLOAD_OFFSET,CAL_PAYLOAD_GAIN_Q_BIT,CAL_PAYLOAD_GAIN_Q_WIDTH,131071);
 bits(table+CAL_TABLE_PAYLOAD_OFFSET,CAL_PAYLOAD_DC_I_BIT,CAL_PAYLOAD_DC_I_WIDTH,-32768);
 bits(table+CAL_TABLE_PAYLOAD_OFFSET,CAL_PAYLOAD_DC_Q_BIT,CAL_PAYLOAD_DC_Q_WIDTH,32767);seal(table);
 assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_OK&&v.gain_i==-131072&&v.gain_q==131071&&v.dc_i==-32768&&v.dc_q==32767);
 table[CAL_TABLE_PAYLOAD_OFFSET+CAL_PAYLOAD_RESERVED_ZERO_BIT/8]|=(uint8_t)(1u<<(CAL_PAYLOAD_RESERVED_ZERO_BIT%8));seal(table);assert(cal_table_validate(table,sizeof table,&expected,&v)==CAL_TABLE_RESERVED&&!v.logical_valid);
 assert(cal_crc32c("123456789",9)==UINT32_C(0xe3069283));
 puts("PASS PS control extensions: event read failures/no POP, decode, calibration CRC/context/time/UNBOUND");return 0;
}
