#include "source_event_control.h"
#include <assert.h>
#include <stdio.h>
static uint32_t mem[0x5000/4];
static int rd(void *ctx,uint32_t a,uint32_t *v){(void)ctx;*v=mem[a/4];return 0;}
static int wr(void *ctx,uint32_t a,uint32_t v){(void)ctx;mem[a/4]=v;return 0;}
int main(void){
 cal_command_io io={0,rd,wr};cal_command_result r={0,14};cal_source_event_snapshot s={0};
 uint32_t p[14]={1,3,55,0,0x20001,2,1,77,7,1,100,0,140,0};
 assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_OK);
 assert(s.token==55&&s.source==2&&s.reason==1&&s.command_sequence==77&&s.config_id==7&&s.accept_gsc==100&&s.drain_gsc==140);
 p[12]=99;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_SCHEMA&&s.drain_gsc==140);p[12]=140;
 p[9]=2;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_SCHEMA);
 p[9]=0;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_SCHEMA);p[10]=0;p[12]=0;
 assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_OK&&s.flags==0);
 p[6]=4;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_SCHEMA);p[6]=0;
 r.code=4;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_COMMAND);r.code=0;
 r.words=13;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_SCHEMA);r.words=14;
 for(unsigned i=0;i<14;i++)p[i]=0;
 p[1]=3;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_EMPTY&&s.dropped==3);
 p[2]=1;assert(cal_source_event_decode(&r,p,&s)==CAL_SOURCE_SCHEMA);
 assert(cal_source_event_peek_begin(&io,1)==CAL_CMD_OK&&mem[CAL_GW_OP_LENGTH/4]==18);
 assert(cal_source_event_pop_begin(&io,2,0)==CAL_CMD_ARGUMENT);
 assert(cal_source_event_pop_begin(&io,2,UINT64_C(0x123456789abcdef0))==CAL_CMD_OK);
 assert(mem[CAL_GW_OP_LENGTH/4]==((2u<<16)|19u)&&mem[CAL_GW_PAYLOAD/4]==0x9abcdef0&&mem[CAL_GW_PAYLOAD/4+1]==0x12345678);
 assert(cal_command_irq_enable(&io,CAL_GW_IRQ_SOURCE_EVENT_AVAILABLE)==CAL_CMD_OK&&mem[CAL_GW_IRQ_ENABLE/4]==4);
 puts("PASS source event C schema time identity empty command token");return 0;
}
