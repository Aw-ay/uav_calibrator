#include <assert.h>
#include <stdio.h>
#include "pdw_control.h"
static uint32_t regs[0x5000/4];
static int rd(void *x,uint32_t a,uint32_t *v){(void)x;*v=regs[a/4];return 0;}
static int wr(void *x,uint32_t a,uint32_t v){(void)x;regs[a/4]=v;return 0;}
int main(void){
 cal_command_io io={0,rd,wr};cal_command_result r={0,20};cal_pdw_snapshot s;
 uint32_t p[20]={1,3,987,0,65537,31,11,0,8,0,7,112,0,12,200,6912,0,2,0,0};
 assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_OK);
 assert(s.count==1&&s.dropped==3&&s.token==987&&s.event.pulse_id==11&&s.event.owner_epoch==8);
 assert(s.event.toa_gsc==112&&s.event.width_ticks==12&&s.event.peak_power==200&&s.event.energy_sum==6912&&s.event.selected_range==2);
 p[18]=1;assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_SCHEMA);assert(s.token==987);p[18]=0;
 r.words=19;assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_SCHEMA);r.words=20;
 r.code=4;assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_COMMAND);r.code=0;
 p[2]=0;assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_SCHEMA);
 for(unsigned i=0;i<20;i++){p[i]=0;}
 p[1]=3;
 assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_EMPTY&&s.count==0&&s.dropped==3);
 p[6]=9;assert(cal_pdw_snapshot_decode(&r,p,&s)==CAL_PDW_SCHEMA);
 assert(cal_pdw_peek_begin(&io,5)==CAL_CMD_OK);assert(regs[CAL_GW_OP_LENGTH/4]==CAL_CMD_PDW_PEEK);
 assert(cal_pdw_pop_begin(&io,6,UINT64_C(0x123456789abcdef0))==CAL_CMD_OK);
 assert(regs[CAL_GW_OP_LENGTH/4]==((2u<<16)|CAL_CMD_PDW_POP));
 assert(regs[CAL_GW_PAYLOAD/4]==0x9abcdef0&&regs[CAL_GW_PAYLOAD/4+1]==0x12345678);
 assert(cal_pdw_pop_begin(&io,7,0)==CAL_CMD_ARGUMENT);
 puts("PASS PDW C decode schema empty token command packing");return 0;
}
