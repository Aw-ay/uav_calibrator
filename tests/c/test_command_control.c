#include "command_control.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static uint32_t mem[0x5000/4],fail_address,submits;
static int read32(void *ctx,uint32_t a,uint32_t *v){(void)ctx;if(a==fail_address)return -1;*v=mem[a/4];return 0;}
static int write32(void *ctx,uint32_t a,uint32_t v){(void)ctx;if(a==CAL_GW_SUBMIT)submits++;if(a==fail_address)return -1;mem[a/4]=v;return 0;}
int main(void){
 cal_command_io io={0,read32,write32};uint32_t p[2]={0x12345678,0xdeadbeef},out[2]={0};cal_command_result result={99,99};
 fail_address=UINT32_MAX;
 assert(cal_command_begin(&io,9,1,55,p)==CAL_CMD_OK);assert(submits==1);
 assert(mem[CAL_GW_PAYLOAD/4]==p[0]&&mem[CAL_GW_OP_LENGTH/4]==0x10009);
 assert(mem[CAL_GW_CRC32C/4]==cal_command_crc(9,1,55,p));
 assert(mem[CAL_GW_CRC32C/4]==0xd67ef2a4u); /* independent Python CRC32C vector */
 mem[CAL_GW_STATUS/4]=1;assert(cal_command_begin(&io,9,1,56,p)==CAL_CMD_BUSY);assert(submits==1);
 assert(cal_command_poll(&io,55,out,2,&result)==CAL_CMD_PENDING);
 mem[CAL_GW_STATUS/4]=2|(5u<<8);mem[CAL_GW_DONE_SEQUENCE/4]=55;mem[CAL_GW_RESULT_LENGTH/4]=2;
 mem[CAL_GW_RESULT/4]=p[0];mem[CAL_GW_RESULT/4+1]=p[1];
 assert(cal_command_poll(&io,56,out,2,&result)==CAL_CMD_SEQUENCE);
 assert(cal_command_poll(&io,55,out,1,&result)==CAL_CMD_CAPACITY);
 assert(cal_command_poll(&io,55,out,2,&result)==CAL_CMD_OK);assert(result.code==5&&result.words==2&&!memcmp(p,out,sizeof p));
 fail_address=CAL_GW_SUBMIT;assert(cal_command_begin(&io,3,0,57,0)==CAL_CMD_SUBMIT_UNKNOWN);assert(submits==2);
 fail_address=CAL_GW_PAYLOAD;assert(cal_command_begin(&io,1,1,58,p)==CAL_CMD_IO);assert(submits==2);
 assert(cal_command_begin(&io,1,257,58,p)==CAL_CMD_ARGUMENT);
 fail_address=UINT32_MAX;
 assert(cal_command_irq_enable(&io,3)==CAL_CMD_OK);assert(mem[0x4020/4]==3);
 assert(cal_command_irq_enable(&io,8)==CAL_CMD_ARGUMENT);assert(mem[0x4020/4]==3);
 mem[0x4024/4]=2;assert(cal_command_irq_status(&io,&out[0])==CAL_CMD_OK&&out[0]==2);
 mem[0x4024/4]=8;assert(cal_command_irq_status(&io,&out[0])==CAL_CMD_PROTOCOL&&out[0]==2);
 fail_address=0x4024;assert(cal_command_irq_status(&io,&out[0])==CAL_CMD_IO&&out[0]==2);
 fail_address=0x4020;assert(cal_command_irq_enable(&io,0)==CAL_CMD_IO);
 assert(cal_command_irq_status(&io,0)==CAL_CMD_ARGUMENT);
 puts("PASS command control ordered submit busy identity capacity RF result ambiguous write no retry");return 0;
}
