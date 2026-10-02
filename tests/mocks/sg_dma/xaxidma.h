#ifndef MOCK_DMA_H
#define MOCK_DMA_H
#include <stdint.h>
#include <stddef.h>
typedef uintptr_t UINTPTR;
typedef struct {UINTPTR address,id;uint32_t length,status;} XAxiDma_Bd;
typedef struct {uint32_t MaxTransferLen;XAxiDma_Bd bd;} XAxiDma_BdRing;
typedef struct {XAxiDma_BdRing ring;} XAxiDma;
typedef struct {int unused;} XAxiDma_Config;
#define XST_SUCCESS 0
#define XAXIDMA_BD_MINIMUM_ALIGNMENT 64
#define XAXIDMA_IRQ_ALL_MASK 7u
#define XAXIDMA_IRQ_ERROR_MASK 4u
#define XAXIDMA_BD_STS_ALL_ERR_MASK 0x70000000u
#define XAXIDMA_BD_STS_COMPLETE_MASK 0x80000000u
#define XAXIDMA_BD_STS_RXSOF_MASK 0x08000000u
#define XAXIDMA_BD_STS_RXEOF_MASK 0x04000000u
#define XAxiDma_GetRxRing(d) (&(d)->ring)
int XAxiDma_CfgInitialize(XAxiDma *,XAxiDma_Config *);
int XAxiDma_HasSg(XAxiDma *);
void XAxiDma_BdRingIntDisable(XAxiDma_BdRing *,uint32_t);
void XAxiDma_BdRingIntEnable(XAxiDma_BdRing *,uint32_t);
uint32_t XAxiDma_BdRingGetIrq(XAxiDma_BdRing *);
void XAxiDma_BdRingAckIrq(XAxiDma_BdRing *,uint32_t);
int XAxiDma_BdRingCreate(XAxiDma_BdRing *,UINTPTR,UINTPTR,unsigned,unsigned);
void XAxiDma_BdClear(XAxiDma_Bd *);
int XAxiDma_BdRingClone(XAxiDma_BdRing *,XAxiDma_Bd *);
int XAxiDma_BdRingSetCoalesce(XAxiDma_BdRing *,unsigned,unsigned);
int XAxiDma_BdRingAlloc(XAxiDma_BdRing *,int,XAxiDma_Bd **);
int XAxiDma_BdSetBufAddr(XAxiDma_Bd *,UINTPTR);
int XAxiDma_BdSetLength(XAxiDma_Bd *,unsigned,unsigned);
void XAxiDma_BdSetCtrl(XAxiDma_Bd *,unsigned);
void XAxiDma_BdSetId(XAxiDma_Bd *,UINTPTR);
int XAxiDma_BdRingToHw(XAxiDma_BdRing *,int,XAxiDma_Bd *);
int XAxiDma_BdRingStart(XAxiDma_BdRing *);
int XAxiDma_BdRingFromHw(XAxiDma_BdRing *,int,XAxiDma_Bd **);
uint32_t XAxiDma_BdGetSts(XAxiDma_Bd *);
uint32_t XAxiDma_BdGetActualLength(XAxiDma_Bd *,unsigned);
UINTPTR XAxiDma_BdGetId(XAxiDma_Bd *);
int XAxiDma_BdRingFree(XAxiDma_BdRing *,int,XAxiDma_Bd *);
#endif
