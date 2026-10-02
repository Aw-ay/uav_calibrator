#include "include/digital_capture_control.h"
#include "include/replay_task_layout.h"
#include "include/instrument_control.h"
cal_command_status cal_replay_budgeted_begin(const cal_command_io *io,uint32_t seq,
 const uint32_t task[48],const cal_capture_budget_input *input,cal_capture_budget *out,int *reason){
 cal_capture_budget_input b;
 if(!task||!input||!out||!reason)return CAL_CMD_ARGUMENT;
 b=*input;b.sample_count=task[CAL_REPLAY_SAMPLE_COUNT_OFFSET/4];
 b.reference_index=task[CAL_REPLAY_REFERENCE_SAMPLE_INDEX_OFFSET/4];
 b.target_gsc=(uint64_t)task[CAL_REPLAY_TARGET_GSC_OFFSET/4]|((uint64_t)task[CAL_REPLAY_TARGET_GSC_OFFSET/4+1]<<32);
 *reason=cal_capture_budget_plan(&b,out);
 if(*reason!=CAL_BUDGET_OK)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_REPLAY,48,seq,task);
}
cal_command_status cal_replay_budgeted_begin_online(const cal_command_io *io,uint32_t seq,
 const uint32_t task[48],const cal_capture_budget_input *input,uint64_t body_end_gsc,cal_capture_budget *out,int *reason){
 cal_capture_budget_input b;
 if(!task||!input||!out||!reason)return CAL_CMD_ARGUMENT;
 b=*input;b.sample_count=task[CAL_REPLAY_SAMPLE_COUNT_OFFSET/4];
 b.reference_index=task[CAL_REPLAY_REFERENCE_SAMPLE_INDEX_OFFSET/4];
 b.target_gsc=(uint64_t)task[CAL_REPLAY_TARGET_GSC_OFFSET/4]|((uint64_t)task[CAL_REPLAY_TARGET_GSC_OFFSET/4+1]<<32);
 *reason=cal_capture_budget_plan_online(&b,body_end_gsc,out);
 if(*reason!=CAL_BUDGET_OK)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_REPLAY,48,seq,task);
}
cal_command_status cal_aux_capture_begin(const cal_command_io *io,uint32_t seq,uint32_t count,uint64_t token){
 uint32_t words[3]={count,(uint32_t)token,(uint32_t)(token>>32)};
 if(!count||count>16384)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_AUX_CAPTURE,3,seq,words);
}
cal_command_status cal_aux_meta_peek_begin(const cal_command_io *io,uint32_t seq){
 return cal_command_begin(io,CAL_CMD_AUX_META_PEEK,0,seq,0);
}
cal_command_status cal_aux_meta_pop_begin(const cal_command_io *io,uint32_t seq,uint32_t id,uint32_t epoch){
 uint32_t words[2]={id,epoch};if(!id)return CAL_CMD_ARGUMENT;
 return cal_command_begin(io,CAL_CMD_AUX_META_POP,2,seq,words);
}
