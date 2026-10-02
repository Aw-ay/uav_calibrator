#include "include/capture_budget.h"
static int add(uint64_t a,uint64_t b,uint64_t *out) {
    if(b>UINT64_MAX-a)return 0;
    *out=a+b;return 1;
}
static int plan(const cal_capture_budget_input *i,cal_capture_budget *out,int online,uint64_t body_end_gsc) {
    cal_capture_budget b;uint64_t release;
    if(!i||!out||!i->sample_count||i->sample_count>16384||
       i->pre_samples>16384||i->reference_index>=i->sample_count)return CAL_BUDGET_INVALID;
    if(i->bounds_valid!=1)return CAL_BUDGET_UNBOUNDED;
    uint64_t available=i->pending_gsc;
    b.scan_ticks=0;
    if(online) {
        uint64_t statistics_ready;
        /* Two power stages + 272 delayed commit + one observation edge.
         * Includes neither finite publish/queue delays nor physical RF latency. */
        if(!add(body_end_gsc,275u*4u,&statistics_ready))return CAL_BUDGET_OVERFLOW;
        if(statistics_ready>available)available=statistics_ready;
    } else {
        /* Diagnostic A-port scanner only: three ranges operate concurrently. */
        b.scan_ticks=((uint64_t)i->sample_count*2+1)*4;
    }
    if(!add(available,i->scan_wait_ticks,&b.ready_gsc)||
       !add(b.ready_gsc,b.scan_ticks,&b.ready_gsc)||
       !add(b.ready_gsc,i->publish_ticks,&b.ready_gsc)||
       !add(b.ready_gsc,i->submit_ticks,&b.earliest_target_gsc)||
       !add(b.earliest_target_gsc,8,&b.earliest_target_gsc)||
       !add(b.earliest_target_gsc,(uint64_t)i->reference_index*4,&b.earliest_target_gsc)||
       !add(b.earliest_target_gsc,i->downstream_ticks,&b.earliest_target_gsc))return CAL_BUDGET_OVERFLOW;
    release=i->upload_release_ticks>i->replay_release_ticks?i->upload_release_ticks:i->replay_release_ticks;
    /* Owner HISTORY=PRE+DETECTOR_LATENCY+1; allow one additional
     * edge before a subsequent trigger can observe ARMED. Continuous samples
     * are required; a missing sample invalidates this finite rearm bound. */
    if(!add(b.ready_gsc,release,&b.rearm_gsc)||
       !add(b.rearm_gsc,((uint64_t)i->pre_samples+i->detector_latency_cycles+2)*4,&b.rearm_gsc))return CAL_BUDGET_OVERFLOW;
    *out=b;
    return i->target_gsc<b.earliest_target_gsc?CAL_BUDGET_LATE:CAL_BUDGET_OK;
}

int cal_capture_budget_plan(const cal_capture_budget_input *i,cal_capture_budget *out) {
    return plan(i,out,0,0);
}
int cal_capture_budget_plan_online(const cal_capture_budget_input *i,uint64_t body_end_gsc,cal_capture_budget *out) {
    return plan(i,out,1,body_end_gsc);
}
