#include "rf_fault_control.h"
#include <assert.h>
#include <stdio.h>
static uint32_t mem[0x5000/4];
static int rd(void *ctx,uint32_t a,uint32_t *v){(void)ctx;*v=mem[a/4];return 0;}
static int wr(void *ctx,uint32_t a,uint32_t v){(void)ctx;mem[a/4]=v;return 0;}
int main(void){
 cal_command_io io={0,rd,wr};cal_command_result r={0,12};cal_rf_fault_snapshot s={0};
 uint32_t p[12]={1,3,55,0,0x30001,3,77,0,0x1c,0x2c,100,0};
 assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_OK);
 assert(s.token==55&&s.flags==3&&s.config_id==77&&s.rf_state==0&&s.normalized_inputs==0x1c&&s.logical_outputs==0x2c&&s.observation_gsc==100);
 p[5]=4;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA&&s.flags==3);p[5]=0;
 assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA);p[6]=0;p[10]=0;
 assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_OK);
 p[7]=5;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA);p[7]=0;
 p[8]=1024;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA);p[8]=0;
 p[9]=64;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA);p[9]=0;
 r.code=4;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_COMMAND);r.code=0;
 r.words=11;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA);r.words=12;
 for(unsigned i=0;i<12;i++)p[i]=0;
 p[1]=3;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_EMPTY&&s.dropped==3);
 p[2]=1;assert(cal_rf_fault_decode(&r,p,&s)==CAL_RF_FAULT_SCHEMA);
 assert(cal_rf_fault_peek_begin(&io,1)==CAL_CMD_OK&&mem[CAL_GW_OP_LENGTH/4]==20);
 assert(cal_rf_fault_pop_begin(&io,2,0)==CAL_CMD_ARGUMENT);
 assert(cal_rf_fault_pop_begin(&io,2,UINT64_C(0x123456789abcdef0))==CAL_CMD_OK);
 assert(mem[CAL_GW_OP_LENGTH/4]==((2u<<16)|21u)&&mem[CAL_GW_PAYLOAD/4]==0x9abcdef0&&mem[CAL_GW_PAYLOAD/4+1]==0x12345678);
 assert(cal_command_irq_enable(&io,CAL_GW_IRQ_RF_FAULT_AVAILABLE)==CAL_CMD_OK&&mem[CAL_GW_IRQ_ENABLE/4]==8);
 puts("PASS RF fault C schema context empty command token");return 0;
}
