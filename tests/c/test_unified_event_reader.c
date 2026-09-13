#include "unified_event_reader.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct {
 uint32_t rows[8][16], latch[16];
 unsigned head, count, ops, pops, reads;
 int fail_count, fail_latch, fail_word, fail_pop;
} model;
static int rd(void *ctx,uint32_t off,uint32_t *v){
 model *m=ctx;m->ops++;
 if(off==REG_EVENT_COUNT){if(m->fail_count)return -1;*v=m->count-m->head;return 0;}
 assert(off>=REG_EVENT_WORD_0);
 unsigned i=(off-REG_EVENT_WORD_0)/(REG_EVENT_WORD_1-REG_EVENT_WORD_0);assert(i<16);
 m->reads++;if((int)i==m->fail_word)return -1;*v=m->latch[i];return 0;
}
static int wr(void *ctx,uint32_t off,uint32_t v){
 model *m=ctx;m->ops++;assert(v==1);
 if(off==REG_EVENT_LATCH){if(m->fail_latch)return -1;assert(m->head<m->count);memcpy(m->latch,m->rows[m->head],sizeof m->latch);return 0;}
 assert(off==REG_EVENT_POP);m->pops++;
 if(m->fail_pop!=1){assert(m->head<m->count);m->head++;}
 return m->fail_pop?-1:0;
}
static void reset(model *m){m->head=0;m->ops=0;m->pops=0;m->reads=0;m->fail_count=0;m->fail_latch=0;m->fail_word=-1;m->fail_pop=0;}
int main(int argc,char **argv){
 model m={0};cal_event_io io={&m,rd,wr};cal_unified_event_reader r,before;unsigned normals=0,faults=0,fi=0;
 assert(argc==3);FILE *f=fopen(argv[1],"r");assert(f);
 while(m.count<8&&fscanf(f,"%x",&m.rows[m.count][0])==1){for(unsigned j=1;j<16;j++)assert(fscanf(f,"%x",&m.rows[m.count][j])==1);m.count++;}fclose(f);assert(m.count==7);
 f=fopen(argv[2],"r");assert(f);for(unsigned j=0;j<16;j++)assert(fscanf(f,"%x",&m.rows[7][j])==1);fclose(f);m.count=8;
 reset(&m);cal_unified_event_init(&r);
 assert(cal_unified_event_fetch(NULL,&r)==CAL_UE_ARGUMENT);
 assert(cal_unified_event_fetch(&io,NULL)==CAL_UE_ARGUMENT);
 cal_event_io bad={&m,NULL,wr};assert(cal_unified_event_fetch(&bad,&r)==CAL_UE_ARGUMENT);
 bad.read32=rd;bad.write32=NULL;assert(cal_unified_event_pop(&bad,&r)==CAL_UE_ARGUMENT);
 assert(cal_unified_event_pop(&io,&r)==CAL_UE_NOT_LATCHED&&m.ops==0);
 for(unsigned i=0;i<m.count;i++){
  assert(cal_unified_event_fetch(&io,&r)==CAL_UE_OK&&m.pops==i);
  if(r.kind==CAL_UE_CAPTURE){normals++;assert(r.decoded.capture.pulse_id==normals);}
  else if(r.kind==CAL_UE_TX){assert(r.decoded.tx.token==1&&r.decoded.tx.command_sequence==7&&r.decoded.tx.flags==3);}
  else {assert(r.kind==CAL_UE_FAULT);faults+=r.decoded.fault.occurrences;fi=i;}
  unsigned ops=m.ops;assert(cal_unified_event_fetch(&io,&r)==CAL_UE_BUSY&&m.ops==ops);
  assert(cal_unified_event_pop(&io,&r)==CAL_UE_OK&&r.state==CAL_UE_IDLE);
 }
 assert(normals==5&&faults==40&&m.reads==128);
 before=r;assert(cal_unified_event_fetch(&io,&r)==CAL_UE_EMPTY&&!memcmp(&r,&before,sizeof r));
 for(unsigned kind=0;kind<2;kind++)for(int j=0;j<16;j++){
  reset(&m);m.head=kind?fi:0;cal_unified_event_init(&r);before=r;m.fail_word=j;
  assert(cal_unified_event_fetch(&io,&r)==CAL_UE_IO_READ&&!memcmp(&r,&before,sizeof r)&&m.pops==0);
  m.fail_word=-1;assert(cal_unified_event_fetch(&io,&r)==CAL_UE_OK);assert(cal_unified_event_pop(&io,&r)==CAL_UE_OK);
 }
 reset(&m);cal_unified_event_init(&r);before=r;m.fail_count=1;
 assert(cal_unified_event_fetch(&io,&r)==CAL_UE_IO_COUNT&&!memcmp(&r,&before,sizeof r)&&m.ops==1);
 m.fail_count=0;m.fail_latch=1;
 assert(cal_unified_event_fetch(&io,&r)==CAL_UE_IO_LATCH&&!memcmp(&r,&before,sizeof r)&&m.pops==0);
 for(int mode=1;mode<=2;mode++){
  reset(&m);cal_unified_event_init(&r);assert(cal_unified_event_fetch(&io,&r)==CAL_UE_OK);before=r;m.fail_pop=mode;
  assert(cal_unified_event_pop(&io,&r)==CAL_UE_POP_UNCERTAIN&&r.state==CAL_UE_UNCERTAIN);
  assert(!memcmp(r.raw,before.raw,sizeof r.raw)&&!memcmp(&r.decoded,&before.decoded,sizeof r.decoded));
  unsigned ops=m.ops;assert(cal_unified_event_pop(&io,&r)==CAL_UE_POP_UNCERTAIN);
  assert(cal_unified_event_fetch(&io,&r)==CAL_UE_POP_UNCERTAIN&&m.ops==ops&&m.pops==1&&m.head==(unsigned)(mode==2));
 }
 reset(&m);cal_unified_event_init(&r);uint32_t tag=m.rows[0][0];m.rows[0][0]=0xdeadbeef;
 assert(cal_unified_event_fetch(&io,&r)==CAL_UE_UNSUPPORTED&&r.kind==CAL_UE_RAW&&m.pops==0&&r.raw[0]==0xef);
 assert(cal_unified_event_pop(&io,&r)==CAL_UE_OK);m.rows[0][0]=tag;
 reset(&m);m.head=fi;m.rows[fi][3]=1;cal_unified_event_init(&r);
 assert(cal_unified_event_fetch(&io,&r)==CAL_UE_INVALID_RECORD&&r.decode_status==CAL_FE_RESERVED&&m.pops==0);
 assert(r.decoded.fault.occurrences==0&&r.state==CAL_UE_SNAPSHOT);
 assert(cal_unified_event_pop(&io,&r)==CAL_UE_OK);
 reset(&m);m.rows[0][1]=UINT32_MAX;cal_unified_event_init(&r);
 assert(cal_unified_event_fetch(&io,&r)==CAL_UE_INVALID_RECORD&&r.kind==CAL_UE_CAPTURE&&r.decode_status==CAL_EVENT_SCHEMA&&m.pops==0);
 assert(r.decoded.capture.pulse_id==0&&cal_unified_event_pop(&io,&r)==CAL_UE_OK);
 puts("PASS unified reader: 8 RTL records including TX, 40 faults, 5 PDWs; 32 word failures; explicit POP and ambiguous completion guard");return 0;
}
