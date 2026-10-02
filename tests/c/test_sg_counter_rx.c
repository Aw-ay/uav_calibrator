#include <windows.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "sg_counter_rx.h"
static cal_sg_counter_rx *s;static unsigned tlb,flush,completed,fromhw,invalidate,freed,irq,payload_bad,length_bad,bd_flags,submit_fail;static uint64_t now;
static uint64_t ticks(void){return now;}
int XAxiDma_CfgInitialize(XAxiDma *d,XAxiDma_Config *c){(void)c;d->ring.MaxTransferLen=0x7fffff;return 0;}
int XAxiDma_HasSg(XAxiDma *d){(void)d;return 1;}
void XAxiDma_BdRingIntDisable(XAxiDma_BdRing *r,uint32_t m){(void)r;(void)m;}
void XAxiDma_BdRingIntEnable(XAxiDma_BdRing *r,uint32_t m){(void)r;(void)m;}
uint32_t XAxiDma_BdRingGetIrq(XAxiDma_BdRing *r){(void)r;return irq;}
void XAxiDma_BdRingAckIrq(XAxiDma_BdRing *r,uint32_t m){(void)r;irq&=~m;}
void Xil_SetTlbAttributes(UINTPTR a,unsigned v){assert(a==(UINTPTR)s->descriptors&&!(a&0x1fffff)&&v==1);tlb=1;}
void Xil_DCacheFlushRange(UINTPTR a,unsigned n){assert(n==CAL_SG_SLOT_BYTES||n==sizeof s->descriptors);(void)a;flush=1;}
void Xil_DCacheInvalidateRange(UINTPTR a,unsigned n){assert(fromhw&&n==CAL_SG_SLOT_BYTES);invalidate=1;for(unsigned i=0;i<s->expected;i++)((unsigned char*)a)[i]=(unsigned char)(i+payload_bad);}
void Xil_Out32(UINTPTR a,uint32_t v){assert(a==0xa0050000u);if(!(v&2))assert(s->active&&flush);}
int XAxiDma_BdRingCreate(XAxiDma_BdRing *r,UINTPTR p,UINTPTR v,unsigned a,unsigned n){(void)r;assert(tlb&&p==v&&a==64&&n==2);return 0;}
void XAxiDma_BdClear(XAxiDma_Bd *b){memset(b,0,sizeof *b);}
int XAxiDma_BdRingClone(XAxiDma_BdRing *r,XAxiDma_Bd *b){r->bd=*b;return 0;}
int XAxiDma_BdRingSetCoalesce(XAxiDma_BdRing *r,unsigned a,unsigned b){(void)r;assert(a==1&&b==0);return 0;}
int XAxiDma_BdRingAlloc(XAxiDma_BdRing *r,int n,XAxiDma_Bd **b){assert(n==1);*b=&r->bd;flush=0;return 0;}
int XAxiDma_BdSetBufAddr(XAxiDma_Bd *b,UINTPTR a){b->address=a;return 0;}
int XAxiDma_BdSetLength(XAxiDma_Bd *b,unsigned n,unsigned m){assert(n<=m);b->length=n;return 0;}
void XAxiDma_BdSetCtrl(XAxiDma_Bd *b,unsigned n){(void)b;assert(!n);}
void XAxiDma_BdSetId(XAxiDma_Bd *b,UINTPTR id){b->id=id;}
int XAxiDma_BdRingToHw(XAxiDma_BdRing *r,int n,XAxiDma_Bd *b){(void)r;assert(n==1&&flush&&s->slots[b->id].state==CAL_DMA_ACTIVE);return submit_fail ? -1 : 0;}
int XAxiDma_BdRingStart(XAxiDma_BdRing *r){(void)r;return 0;}
int XAxiDma_BdRingFromHw(XAxiDma_BdRing *r,int n,XAxiDma_Bd **b){assert(n==1);if(!completed)return 0;*b=&r->bd;fromhw=1;return 1;}
uint32_t XAxiDma_BdGetSts(XAxiDma_Bd *b){(void)b;return bd_flags;}
uint32_t XAxiDma_BdGetActualLength(XAxiDma_Bd *b,unsigned n){(void)b;(void)n;return s->expected+length_bad;}
UINTPTR XAxiDma_BdGetId(XAxiDma_Bd *b){return b->id;}
int XAxiDma_BdRingFree(XAxiDma_BdRing *r,int n,XAxiDma_Bd *b){(void)r;(void)n;assert(invalidate&&s->slots[b->id].state==CAL_DMA_USER_OWNED);freed++;return 0;}
static void init(void){XAxiDma_Config c={0};now=0;tlb=flush=completed=fromhw=invalidate=freed=irq=payload_bad=length_bad=submit_fail=0;bd_flags=0x8c000000;assert(!cal_sg_counter_init(s,&c,0xa0050000u,100,ticks));}
int main(void){s=VirtualAlloc((void*)0x20000000,sizeof *s,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);assert(s==(void*)0x20000000);init();
 for(unsigned n=1;n<=257;n+=16){completed=fromhw=invalidate=0;assert(!cal_sg_counter_start(s,n));completed=1;assert(!cal_sg_counter_poll(s)&&!invalidate);irq=1;cal_sg_counter_irq(s);assert(cal_sg_counter_poll(s)==1);assert(s->actual==n&&s->slots[s->token.index].state==CAL_DMA_FREE);}
 init();assert(!cal_sg_counter_start(s,17));completed=1;irq=1;length_bad=1;cal_sg_counter_irq(s);assert(cal_sg_counter_poll(s)<0&&!invalidate&&!freed&&s->fault);assert(s->slots[s->token.index].state==CAL_DMA_ACTIVE);
 init();assert(!cal_sg_counter_start(s,17));completed=1;irq=1;payload_bad=1;cal_sg_counter_irq(s);assert(cal_sg_counter_poll(s)<0&&invalidate&&!freed&&s->slots[0].state==CAL_DMA_USER_OWNED);
 init();assert(!cal_sg_counter_start(s,17));now=101;assert(cal_sg_counter_poll(s)<0&&!freed&&(s->control&2));
 init();assert(!cal_sg_counter_start(s,17));irq=4;cal_sg_counter_irq(s);assert(cal_sg_counter_poll(s)<0&&!freed);
 for(unsigned mask=0x04000000;mask<=0x08000000;mask<<=1){init();assert(!cal_sg_counter_start(s,17));completed=1;irq=1;bd_flags&=~mask;cal_sg_counter_irq(s);assert(cal_sg_counter_poll(s)<0&&!invalidate&&!freed);}
 init();submit_fail=1;assert(cal_sg_counter_start(s,17)<0&&s->slots[0].state==CAL_DMA_ACTIVE&&!freed);
 puts("PASS SG service mock: cache ordering, IRQ required, actual length, SG/slot return, timeout/error quarantine");return 0;}
