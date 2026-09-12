#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "waveform_control.h"
static uint32_t regs[0x5000/4];
static unsigned writes;
static int rd(void *ctx,uint32_t a,uint32_t *v){(void)ctx;*v=regs[a/4];return 0;}
static int wr(void *ctx,uint32_t a,uint32_t v){(void)ctx;writes++;regs[a/4]=v;return 0;}
int main(void){
 cal_command_io io={0,rd,wr};
 cal_dds_command d={UINT64_C(0x1122334455667788),4,6,2,UINT64_C(0x123456789abc),UINT64_C(0xfedcba987654),1};
 const uint32_t expected[9]={0x55667788,0x11223344,4,6,2,0x56789abc,0x76541234,0xfedcba98,1};
 const uint64_t samples[2]={UINT64_C(0x0004000300020001),UINT64_C(0xfffcfffdfffeffff)};
 unsigned before;
 assert(cal_dds_begin(&io,19,&d)==CAL_CMD_OK);
 assert(regs[CAL_GW_OP_LENGTH/4]==((9u<<16)|CAL_CMD_DDS));
 assert(memcmp(&regs[CAL_GW_PAYLOAD/4],expected,sizeof expected)==0);
 assert(regs[CAL_GW_CRC32C/4]==cal_command_crc(CAL_CMD_DDS,9,19,expected));
 before=writes;d.start_gsc++;assert(cal_dds_begin(&io,20,&d)==CAL_CMD_ARGUMENT);d.start_gsc--;
 d.pw_samples=0;assert(cal_dds_begin(&io,20,&d)==CAL_CMD_ARGUMENT);d.pw_samples=7;
 assert(cal_dds_begin(&io,20,&d)==CAL_CMD_ARGUMENT);d.pw_samples=4;
 d.initial_pinc=UINT64_C(1)<<48;assert(cal_dds_begin(&io,20,&d)==CAL_CMD_ARGUMENT);d.initial_pinc=1;
 d.reset_each_pulse=2;assert(cal_dds_begin(&io,20,&d)==CAL_CMD_ARGUMENT);d.reset_each_pulse=1;
 d.start_gsc=UINT64_MAX-3;assert(cal_dds_begin(&io,20,&d)==CAL_CMD_ARGUMENT);
 assert(cal_dds_begin(&io,20,0)==CAL_CMD_ARGUMENT);assert(writes==before);
 /* Independent CRC value from byte-oriented Python model. */
 assert(cal_awg_crc32c(samples,2)==0xc8722d03u);
 assert(cal_awg_load_begin(&io,21,2,0xc8722d03)==CAL_CMD_OK);
 assert(regs[CAL_GW_OP_LENGTH/4]==((5u<<16)|CAL_CMD_AWG_LOAD));
 assert(regs[CAL_GW_PAYLOAD/4]==0&&regs[CAL_GW_PAYLOAD/4+1]==2&&regs[CAL_GW_PAYLOAD/4+2]==0xc8722d03);
 assert(cal_awg_write(&io,22,samples[1])==CAL_CMD_OK);
 assert(regs[CAL_GW_PAYLOAD/4]==1&&regs[CAL_GW_PAYLOAD/4+3]==0xfffeffff&&regs[CAL_GW_PAYLOAD/4+4]==0xfffcfffd);
 assert(cal_awg_commit(&io,23)==CAL_CMD_OK);assert(regs[CAL_GW_PAYLOAD/4]==2);
 assert(cal_awg_play(&io,24)==CAL_CMD_OK);assert(regs[CAL_GW_OP_LENGTH/4]==CAL_CMD_AWG_PLAY);
 before=writes;assert(cal_awg_load_begin(&io,25,0,0)==CAL_CMD_ARGUMENT);assert(writes==before);
 regs[CAL_GW_STATUS/4]=1;assert(cal_awg_play(&io,25)==CAL_CMD_BUSY);assert(writes==before);
 puts("PASS typed waveform packing bounds CRC and no writes on invalid/busy");return 0;
}
