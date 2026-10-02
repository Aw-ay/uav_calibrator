#include "capture_budget.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
int main(void) {
    cal_capture_budget_input i={0}; cal_capture_budget o={0};
    i.sample_count=16384; i.pre_samples=250; i.bounds_valid=1;
    i.pending_gsc=1000; i.scan_wait_ticks=400; i.publish_ticks=100;
    i.upload_release_ticks=10000; i.replay_release_ticks=20000;
    i.downstream_ticks=168; i.target_gsc=1000000;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_OK);
    assert(o.scan_ticks==131076); /* 32769 clocks, 262.152 us */
    assert(o.ready_gsc==132576 && o.earliest_target_gsc==132752);
    assert(o.rearm_gsc==153584); /* max consumers, then owner history + observation edge */
    i.target_gsc=o.earliest_target_gsc;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_OK);
    i.target_gsc--;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_LATE);
    i.target_gsc=1000000; i.sample_count=15500;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_OK && o.scan_ticks==124004);
    i.bounds_valid=0; assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_UNBOUNDED);
    i.bounds_valid=1; i.pending_gsc=UINT64_MAX-1;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_OVERFLOW);
    i.pending_gsc=0; i.reference_index=i.sample_count;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_INVALID);
    i.reference_index=0; i.sample_count=0;
    assert(cal_capture_budget_plan(&i,&o)==CAL_BUDGET_INVALID);
    i.sample_count=15500;i.pending_gsc=1000;i.reference_index=0;
    assert(cal_capture_budget_plan_online(&i,900,&o)==CAL_BUDGET_OK);
    assert(o.scan_ticks==0&&o.ready_gsc==2500&&o.earliest_target_gsc==2676);
    assert(o.rearm_gsc==23508);
    i.pending_gsc=3000; /* POST is longer than the statistics commit delay. */
    assert(cal_capture_budget_plan_online(&i,900,&o)==CAL_BUDGET_OK&&o.ready_gsc==3500);
    i.target_gsc=o.earliest_target_gsc-1;
    assert(cal_capture_budget_plan_online(&i,900,&o)==CAL_BUDGET_LATE);
    i.bounds_valid=0;
    assert(cal_capture_budget_plan_online(&i,900,&o)==CAL_BUDGET_UNBOUNDED);
    i.bounds_valid=1;
    assert(cal_capture_budget_plan_online(&i,UINT64_MAX-100,&o)==CAL_BUDGET_OVERFLOW);
    puts("PASS capture bank/DRFM budget: diagnostic scan and normal online join, release, deadline, unbounded, overflow");
}
