#ifndef CAL_SG_COUNTER_RX_H
#define CAL_SG_COUNTER_RX_H
#include "xaxidma.h"
#include "../common/dma_slots.h"
#define CAL_SG_SLOT_BYTES 262144u
#define CAL_SG_SLOTS 2u
typedef struct {
 XAxiDma dma;
 cal_dma_pool pool;cal_dma_slot slots[CAL_SG_SLOTS];cal_dma_token token;
 /* Dedicated A53 2 MiB MMU block; no unrelated objects share this range. */
 unsigned char descriptors[0x200000] __attribute__((aligned(0x200000)));
 unsigned char buffers[CAL_SG_SLOTS][CAL_SG_SLOT_BYTES] __attribute__((aligned(64)));
 UINTPTR control_base;
 volatile uint32_t irq_count,irq_error;
 uint32_t irq_at_submit,expected,actual,completed,control;
 unsigned active,fault,next_slot;
 uint64_t submitted_at,timeout_ticks;
 uint64_t (*ticks)(void);
} cal_sg_counter_rx;
/* Caller supplies current XSA BSP config and connects cal_sg_counter_irq to
 * the BSP-derived S2MM IRQ before start. No guessed IRQ/DDR addresses. */
int cal_sg_counter_init(cal_sg_counter_rx *,XAxiDma_Config *,UINTPTR,uint64_t,uint64_t (*)(void));
int cal_sg_counter_start(cal_sg_counter_rx *,uint32_t);
/* 0 waiting, 1 verified and returned, negative fault (storage quarantined). */
int cal_sg_counter_poll(cal_sg_counter_rx *);
void cal_sg_counter_irq(void *);
#endif
