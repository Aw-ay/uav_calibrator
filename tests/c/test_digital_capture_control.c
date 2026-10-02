#include "digital_capture_control.h"
#include "replay_task_layout.h"
#include <assert.h>
#include <stdio.h>
static unsigned writes;static uint32_t op;
static int rd(void *c,uint32_t a,uint32_t *v){(void)c;(void)a;*v=0;return 0;}
static int wr(void *c,uint32_t a,uint32_t v){(void)c;writes++;if(a==CAL_GW_OP_LENGTH)op=v;return 0;}
int main(void){
 cal_command_io io={0,rd,wr};uint32_t task[48]={0};cal_capture_budget_input in={0};cal_capture_budget out;int reason=-1;
 task[CAL_REPLAY_SAMPLE_COUNT_OFFSET/4]=16384;task[CAL_REPLAY_TARGET_GSC_OFFSET/4]=1000000;
 in.sample_count=1; /* helper must derive count from the actual serialized task */
 in.bounds_valid=1;in.pre_samples=250;in.downstream_ticks=168;
 assert(cal_replay_budgeted_begin(&io,1,task,&in,&out,&reason)==CAL_CMD_OK&&reason==0&&out.scan_ticks==131076);
 assert((op&65535)==9&&op>>16==48);
 writes=0;in.bounds_valid=0;
 assert(cal_replay_budgeted_begin(&io,2,task,&in,&out,&reason)==CAL_CMD_ARGUMENT&&reason==CAL_BUDGET_UNBOUNDED&&writes==0);
 in.bounds_valid=1;task[CAL_REPLAY_TARGET_GSC_OFFSET/4]=1;
 assert(cal_replay_budgeted_begin(&io,3,task,&in,&out,&reason)==CAL_CMD_ARGUMENT&&reason==CAL_BUDGET_LATE&&writes==0);
 assert(cal_aux_capture_begin(&io,4,8,UINT64_C(0xfedcba9876543210))==CAL_CMD_OK&&(op&65535)==22&&op>>16==3);
 assert(cal_aux_meta_peek_begin(&io,5)==CAL_CMD_OK&&(op&65535)==23);
 assert(cal_aux_meta_pop_begin(&io,6,1,9)==CAL_CMD_OK&&(op&65535)==24);
 task[CAL_REPLAY_TARGET_GSC_OFFSET/4]=1000000;writes=0;
 assert(cal_replay_budgeted_begin_online(&io,7,task,&in,900,&out,&reason)==CAL_CMD_OK&&reason==0&&out.scan_ticks==0&&out.ready_gsc==2000);
 task[CAL_REPLAY_TARGET_GSC_OFFSET/4]=1;writes=0;
 assert(cal_replay_budgeted_begin_online(&io,8,task,&in,900,&out,&reason)==CAL_CMD_ARGUMENT&&reason==CAL_BUDGET_LATE&&writes==0);
 puts("PASS digital control: budget gates actual REPLAY submit, AUX command helpers");
}
