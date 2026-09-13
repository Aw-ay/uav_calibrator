#include "unified_event_reader.h"
#include "replay_identity_decode.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#endif
typedef struct {uint32_t words[16];unsigned count,pops,latches;} mock;
static int rd(void *ctx,uint32_t off,uint32_t *v){mock *m=ctx;if(off==REG_EVENT_COUNT){*v=m->count;return 0;}
 assert(off>=REG_EVENT_WORD_0&&off<=REG_EVENT_WORD_15);*v=m->words[(off-REG_EVENT_WORD_0)/4];return 0;}
static int wr(void *ctx,uint32_t off,uint32_t v){mock *m=ctx;assert(v==1);
 if(off==REG_EVENT_LATCH){m->latches++;return 0;}assert(off==REG_EVENT_POP&&m->count);m->count--;m->pops++;return 0;}
int main(int argc,char **argv){
#ifdef _WIN32
 SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX);
#endif
 assert(argc==2);FILE *f=fopen(argv[1],"r");assert(f);mock m={0};unsigned rows=0;
 cal_replay_identity event={0},before;uint8_t bytes[64];cal_event_io io={&m,rd,wr};cal_unified_event_reader reader;
 while(fscanf(f,"%x",&m.words[0])==1){
  for(unsigned w=0;w<16;w++){if(w)assert(fscanf(f,"%x",&m.words[w])==1);for(unsigned b=0;b<4;b++)bytes[w*4+b]=(uint8_t)(m.words[w]>>(8*b));}
  assert(cal_replay_identity_decode(bytes,64,&event)==CAL_RI_OK);
  if(rows==0){assert(event.token==UINT64_C(0x1234567887654321)&&event.task_id==UINT64_C(0xfedcba9876543210));
   assert(event.pulse_id==UINT64_C(0x1122334455667788)&&event.owner_epoch==UINT64_C(0xabcdef0102030405)&&event.generation==UINT64_C(0x8877665544332211));
   assert(event.config_id==7&&event.fir_id==9&&event.source_epoch==11&&event.group==3&&event.bank==2);
  }else assert(event.token==UINT64_MAX&&event.task_id==0&&event.group==1&&event.bank==0);
  before=event;bytes[4]=1;assert(cal_replay_identity_decode(bytes,64,&event)==CAL_RI_RESERVED&&!memcmp(&event,&before,sizeof event));bytes[4]=0;
  bytes[60]=0;assert(cal_replay_identity_decode(bytes,64,&event)==CAL_RI_VALUE);bytes[60]=(uint8_t)before.group;
  bytes[62]=4;assert(cal_replay_identity_decode(bytes,64,&event)==CAL_RI_VALUE);bytes[62]=(uint8_t)before.bank;
  for(unsigned b=8;b<16;b++)bytes[b]=0;assert(cal_replay_identity_decode(bytes,64,&event)==CAL_RI_VALUE);
  m.count=1;m.pops=0;m.latches=0;cal_unified_event_init(&reader);
  assert(cal_unified_event_fetch(&io,&reader)==CAL_UE_OK&&reader.kind==CAL_UE_REPLAY_IDENTITY&&m.pops==0);
  assert(reader.decoded.replay_identity.token==before.token&&reader.decoded.replay_identity.task_id==before.task_id);
  assert(cal_unified_event_pop(&io,&reader)==CAL_UE_OK&&m.pops==1&&m.count==0);
  m.count=1;m.words[1]=1;cal_unified_event_init(&reader);
  assert(cal_unified_event_fetch(&io,&reader)==CAL_UE_INVALID_RECORD&&reader.raw[4]==1&&reader.kind==CAL_UE_REPLAY_IDENTITY&&m.pops==1);
  assert(cal_unified_event_pop(&io,&reader)==CAL_UE_OK&&m.pops==2);rows++;
 }
 fclose(f);assert(rows==2);
 assert(cal_replay_identity_decode(NULL,64,&event)==CAL_RI_ARGUMENT);assert(cal_replay_identity_decode(bytes,63,&event)==CAL_RI_SHORT);
 puts("PASS replay identity C decode actual RTL full64 and unified fetch explicit POP malformed retention");return 0;
}
