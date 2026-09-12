#ifndef CAL_DMA_SLOTS_H
#define CAL_DMA_SLOTS_H
#include <stddef.h>
#include <stdint.h>

#define CAL_DMA_ADDRESS_BITS 40u
#define CAL_DMA_ALIGNMENT 64u
typedef enum { CAL_DMA_FREE=0, CAL_DMA_DRIVER_OWNED, CAL_DMA_ACTIVE, CAL_DMA_COMPLETE, CAL_DMA_USER_OWNED } cal_dma_state;
typedef enum { CAL_DMA_OK=0, CAL_DMA_NULL, CAL_DMA_BOUNDS, CAL_DMA_STATE, CAL_DMA_STALE, CAL_DMA_ADDRESS, CAL_DMA_LENGTH, CAL_DMA_BUSY } cal_dma_status;
typedef struct { size_t index; uint64_t generation; } cal_dma_token;
typedef struct { cal_dma_state state; uint64_t generation, dma_address; uint32_t actual_bytes, completion_error; } cal_dma_slot;
typedef struct { cal_dma_slot *slots; size_t count; uint32_t slot_bytes; } cal_dma_pool;

/* Cold initialization only. slots must name a writable extent of count elements. */
cal_dma_status cal_dma_pool_init(cal_dma_pool *, cal_dma_slot *, size_t, uint32_t);
cal_dma_status cal_dma_claim(cal_dma_pool *, size_t, uint64_t, cal_dma_token *);
cal_dma_status cal_dma_activate(cal_dma_pool *, cal_dma_token);
cal_dma_status cal_dma_complete(cal_dma_pool *, cal_dma_token, uint32_t, uint32_t);
cal_dma_status cal_dma_acquire_complete(cal_dma_pool *, size_t, cal_dma_token *);
cal_dma_status cal_dma_release(cal_dma_pool *, cal_dma_token);
cal_dma_status cal_dma_cancel_owned(cal_dma_pool *, cal_dma_token);
/* Requires every slot FREE; advances all generations and clears DMA results. */
cal_dma_status cal_dma_pool_reset(cal_dma_pool *);
#endif
