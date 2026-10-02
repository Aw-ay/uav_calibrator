#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "fine_control.h"
static uint32_t regs[0x5000/4];
static int rd(void *x,uint32_t a,uint32_t *v){(void)x;*v=regs[a/4];return 0;}
static int wr(void *x,uint32_t a,uint32_t v){(void)x;regs[a/4]=v;return 0;}
int main(void){
 cal_command_io io={0,rd,wr};cal_command_result r={0,36};cal_fine_snapshot s;
 uint32_t w[36]={1,2,987,0},*p=w+4;p[0]=CAL_FINE_PDW_TAG;p[1]=3;p[2]=11;p[4]=8;p[6]=9;p[8]=7;p[9]=0x1f010202;p[10]=112;
 p[12]=65537;p[13]=1234567;p[20]=(uint32_t)-12345;p[22]=(uint32_t)INT64_C(-9000000000000);p[23]=(uint32_t)((uint64_t)INT64_C(-9000000000000)>>32);p[26]=(uint32_t)-536870912;p[27]=0xffffffff;p[29]=0x12340040;p[30]=0x102004;
 assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_OK);
 assert(s.count==1&&s.token==987&&s.pdw.range_id==2&&s.pdw.bank_id==2&&s.pdw.selected==1&&s.pdw.valid_mask==31);
 assert(s.pdw.pulse_id==11&&s.pdw.owner_epoch==8&&s.pdw.generation==9&&s.pdw.config_id==7&&s.pdw.gsc_first==112);
 assert(s.pdw.frequency_hz[0]==-12345&&s.pdw.chirp_hz_per_s[0]==INT64_C(-9000000000000)&&s.pdw.hv_phase_q31==-536870912);
 assert(s.pdw.edge_quality[1]==0x1234&&s.pdw.spectral_quality[2]==16&&s.pdw.snr_q16[0]==0xffffffff);
 p[31]=1;assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_SCHEMA&&s.token==987);p[31]=0;
 r.words=35;assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_SCHEMA);r.words=36;
 r.code=4;assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_COMMAND);r.code=0;
 w[0]=65;assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_SCHEMA);
 memset(w,0,sizeof w);w[1]=3;assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_EMPTY&&s.dropped==3);
 w[5]=1;assert(cal_fine_snapshot_decode(&r,w,&s)==CAL_FINE_SCHEMA);
 assert(cal_fine_peek_begin(&io,1)==CAL_CMD_OK&&regs[CAL_GW_OP_LENGTH/4]==25);
 assert(cal_fine_pop_begin(&io,2,UINT64_C(0x123456789abcdef0))==CAL_CMD_OK);
 assert(regs[CAL_GW_OP_LENGTH/4]==((2u<<16)|26u)&&regs[CAL_GW_PAYLOAD/4]==0x9abcdef0&&regs[CAL_GW_PAYLOAD/4+1]==0x12345678);
 assert(cal_fine_pop_begin(&io,3,0)==CAL_CMD_ARGUMENT);
 assert(cal_command_irq_enable(&io,CAL_GW_IRQ_FINE_PDW_AVAILABLE)==CAL_CMD_OK);
 puts("PASS Fine C decode signed frequency/chirp/HV, schema, empty queue, exact token commands and IRQ mask");return 0;
}
