#include "sg_counter_rx.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_mmu.h"
#include <string.h>
static void sync_dma(void){
#ifdef __aarch64__
 __asm__ volatile("dsb sy" ::: "memory");
#endif
}
static int fail(cal_sg_counter_rx *s){
 s->fault=1;s->control|=2u;Xil_Out32(s->control_base,s->control);
 XAxiDma_BdRingIntDisable(XAxiDma_GetRxRing(&s->dma),XAXIDMA_IRQ_ALL_MASK);
 /* Do not free ACTIVE BDs after timeout/error. Recovery needs DMA + source
  * coordinated reset and hardware quiescence; bank/slot generations stay live. */
 return -1;
}
int cal_sg_counter_init(cal_sg_counter_rx *s,XAxiDma_Config *cfg,UINTPTR gpio,uint64_t timeout,uint64_t (*ticks)(void)){
 XAxiDma_Bd blank;XAxiDma_BdRing *ring;
 if(!s||!cfg||!gpio||!timeout||!ticks)return -1;
 memset(s,0,sizeof *s);s->control_base=gpio;s->ticks=ticks;s->timeout_ticks=timeout;s->control=2;
 Xil_Out32(gpio,2); /* stop new packets before touching DMA */
 if(XAxiDma_CfgInitialize(&s->dma,cfg)!=XST_SUCCESS){s->fault=1;return -1;}
 if(!XAxiDma_HasSg(&s->dma))return fail(s);
 ring=XAxiDma_GetRxRing(&s->dma);XAxiDma_BdRingIntDisable(ring,XAXIDMA_IRQ_ALL_MASK);
 if(cal_dma_pool_init(&s->pool,s->slots,CAL_SG_SLOTS,CAL_SG_SLOT_BYTES)!=CAL_DMA_OK)return fail(s);
 Xil_DCacheFlushRange((UINTPTR)s->descriptors,sizeof s->descriptors);
 Xil_SetTlbAttributes((UINTPTR)s->descriptors,NORM_NONCACHE);
 if(XAxiDma_BdRingCreate(ring,(UINTPTR)s->descriptors,(UINTPTR)s->descriptors,XAXIDMA_BD_MINIMUM_ALIGNMENT,CAL_SG_SLOTS)!=XST_SUCCESS)return fail(s);
 XAxiDma_BdClear(&blank);
 if(XAxiDma_BdRingClone(ring,&blank)!=XST_SUCCESS||XAxiDma_BdRingSetCoalesce(ring,1,0)!=XST_SUCCESS)return fail(s);
 XAxiDma_BdRingAckIrq(ring,XAXIDMA_IRQ_ALL_MASK);
 XAxiDma_BdRingIntEnable(ring,XAXIDMA_IRQ_ALL_MASK);return 0;
}
void cal_sg_counter_irq(void *arg){
 cal_sg_counter_rx *s=arg;XAxiDma_BdRing *ring=XAxiDma_GetRxRing(&s->dma);
 uint32_t irq=XAxiDma_BdRingGetIrq(ring);XAxiDma_BdRingAckIrq(ring,irq);
 if(irq&XAXIDMA_IRQ_ERROR_MASK)s->irq_error|=irq;
 if(irq&XAXIDMA_IRQ_ALL_MASK)++s->irq_count;
}
int cal_sg_counter_start(cal_sg_counter_rx *s,uint32_t bytes){
 XAxiDma_Bd *bd;XAxiDma_BdRing *ring;UINTPTR address;
 if(!s||s->fault||s->active||!bytes||bytes>CAL_SG_SLOT_BYTES)return -1;
 ring=XAxiDma_GetRxRing(&s->dma);address=(UINTPTR)s->buffers[s->next_slot];
 if(cal_dma_claim(&s->pool,s->next_slot,address,&s->token)!=CAL_DMA_OK)return fail(s);
 if(XAxiDma_BdRingAlloc(ring,1,&bd)!=XST_SUCCESS){(void)cal_dma_cancel_owned(&s->pool,s->token);return fail(s);}
 if(XAxiDma_BdSetBufAddr(bd,address)!=XST_SUCCESS||XAxiDma_BdSetLength(bd,CAL_SG_SLOT_BYTES,ring->MaxTransferLen)!=XST_SUCCESS)return fail(s);
 XAxiDma_BdSetCtrl(bd,0);XAxiDma_BdSetId(bd,s->next_slot);
 /* Full cache-line isolated slot: clean dirty CPU lines BEFORE S2MM. */
 Xil_DCacheFlushRange(address,CAL_SG_SLOT_BYTES);
 s->expected=bytes;s->actual=0;s->irq_at_submit=s->irq_count;s->submitted_at=s->ticks();
 if(cal_dma_activate(&s->pool,s->token)!=CAL_DMA_OK)return fail(s);
 s->active=1;
 sync_dma();
 if(XAxiDma_BdRingToHw(ring,1,bd)!=XST_SUCCESS||XAxiDma_BdRingStart(ring)!=XST_SUCCESS)return fail(s);
 /* A53 BD cache macros are empty: descriptors use a dedicated noncache block. */
 sync_dma();
 s->control=(bytes<<8)|((s->control^1u)&1u);Xil_Out32(s->control_base,s->control);return 0;
}
int cal_sg_counter_poll(cal_sg_counter_rx *s){
 XAxiDma_Bd *bd;XAxiDma_BdRing *ring;uint32_t flags,actual;int count;cal_dma_token user;
 if(!s||s->fault)return -1;
 if(!s->active)return 0;
 if(s->irq_error)return fail(s);
 if(s->ticks()-s->submitted_at>s->timeout_ticks)return fail(s);
 if(s->irq_count==s->irq_at_submit)return 0; /* polling is not IRQ proof */
 ring=XAxiDma_GetRxRing(&s->dma);count=XAxiDma_BdRingFromHw(ring,1,&bd);
 if(!count)return 0;
 flags=XAxiDma_BdGetSts(bd);actual=XAxiDma_BdGetActualLength(bd,ring->MaxTransferLen);s->actual=actual;
 if(count!=1||(flags&XAXIDMA_BD_STS_ALL_ERR_MASK)||
   (flags&(XAXIDMA_BD_STS_COMPLETE_MASK|XAXIDMA_BD_STS_RXSOF_MASK|XAXIDMA_BD_STS_RXEOF_MASK))!=(XAXIDMA_BD_STS_COMPLETE_MASK|XAXIDMA_BD_STS_RXSOF_MASK|XAXIDMA_BD_STS_RXEOF_MASK)||
   XAxiDma_BdGetId(bd)!=s->token.index||actual!=s->expected||actual>CAL_SG_SLOT_BYTES)return fail(s);
 /* BD storage is noncache. Invalidate payload only after DMA completion. */
 Xil_DCacheInvalidateRange((UINTPTR)s->buffers[s->token.index],CAL_SG_SLOT_BYTES);
 if(cal_dma_complete(&s->pool,s->token,actual,0)!=CAL_DMA_OK||cal_dma_acquire_complete(&s->pool,s->token.index,&user)!=CAL_DMA_OK)return fail(s);
 for(uint32_t i=0;i<actual;i++)if(s->buffers[user.index][i]!=(unsigned char)i)return fail(s);
 if(XAxiDma_BdRingFree(ring,1,bd)!=XST_SUCCESS||cal_dma_release(&s->pool,user)!=CAL_DMA_OK)return fail(s);
 s->actual=actual;s->active=0;++s->completed;s->next_slot=(s->next_slot+1)%CAL_SG_SLOTS;return 1;
}
