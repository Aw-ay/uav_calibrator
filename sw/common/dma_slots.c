#include "dma_slots.h"

#include <string.h>

static void next_generation(cal_dma_slot *slot)
{
    ++slot->generation;
    if (!slot->generation) {
        ++slot->generation;
    }
}

static cal_dma_status slot_for(cal_dma_pool *pool, cal_dma_token token,
                               cal_dma_slot **slot)
{
    if (!pool || !pool->slots || !slot) {
        return CAL_DMA_NULL;
    }
    if (token.index >= pool->count) {
        return CAL_DMA_BOUNDS;
    }

    *slot = &pool->slots[token.index];
    return ((*slot)->generation == token.generation) ? CAL_DMA_OK : CAL_DMA_STALE;
}

cal_dma_status cal_dma_pool_init(cal_dma_pool *pool, cal_dma_slot *slots,
                                 size_t count, uint32_t slot_bytes)
{
    if (!pool || !slots) {
        return CAL_DMA_NULL;
    }
    if (!count || !slot_bytes || count > SIZE_MAX / sizeof(*slots)) {
        return CAL_DMA_BOUNDS;
    }

    memset(slots, 0, count * sizeof(*slots));
    pool->slots = slots;
    pool->count = count;
    pool->slot_bytes = slot_bytes;
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_claim(cal_dma_pool *pool, size_t index,
                             uint64_t address, cal_dma_token *token)
{
    cal_dma_slot *slot;
    size_t other_index;
    uint64_t limit = UINT64_C(1) << CAL_DMA_ADDRESS_BITS;
    uint64_t end;

    if (!pool || !pool->slots || !token) {
        return CAL_DMA_NULL;
    }
    if (index >= pool->count) {
        return CAL_DMA_BOUNDS;
    }
    if ((address & (CAL_DMA_ALIGNMENT - 1u)) || address >= limit ||
        pool->slot_bytes > limit - address) {
        return CAL_DMA_ADDRESS;
    }

    end = address + pool->slot_bytes;
    slot = &pool->slots[index];
    if (slot->state != CAL_DMA_FREE) {
        return CAL_DMA_STATE;
    }

    for (other_index = 0; other_index < pool->count; ++other_index) {
        uint64_t other_end;

        if (other_index == index ||
            pool->slots[other_index].state == CAL_DMA_FREE) {
            continue;
        }
        other_end = pool->slots[other_index].dma_address + pool->slot_bytes;
        if (address < other_end &&
            pool->slots[other_index].dma_address < end) {
            return CAL_DMA_ADDRESS;
        }
    }

    next_generation(slot);
    slot->state = CAL_DMA_DRIVER_OWNED;
    slot->dma_address = address;
    slot->actual_bytes = 0;
    slot->completion_error = 0;
    token->index = index;
    token->generation = slot->generation;
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_activate(cal_dma_pool *pool, cal_dma_token token)
{
    cal_dma_slot *slot;
    cal_dma_status status = slot_for(pool, token, &slot);

    if (status) {
        return status;
    }
    if (slot->state != CAL_DMA_DRIVER_OWNED) {
        return CAL_DMA_STATE;
    }

    slot->state = CAL_DMA_ACTIVE;
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_complete(cal_dma_pool *pool, cal_dma_token token,
                                uint32_t actual_bytes, uint32_t error)
{
    cal_dma_slot *slot;
    cal_dma_status status = slot_for(pool, token, &slot);

    if (status) {
        return status;
    }
    if (slot->state != CAL_DMA_ACTIVE) {
        return CAL_DMA_STATE;
    }
    if (actual_bytes > pool->slot_bytes) {
        return CAL_DMA_LENGTH;
    }

    slot->actual_bytes = actual_bytes;
    slot->completion_error = error;
    slot->state = CAL_DMA_COMPLETE;
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_acquire_complete(cal_dma_pool *pool, size_t index,
                                        cal_dma_token *token)
{
    cal_dma_slot *slot;

    if (!pool || !pool->slots || !token) {
        return CAL_DMA_NULL;
    }
    if (index >= pool->count) {
        return CAL_DMA_BOUNDS;
    }

    slot = &pool->slots[index];
    if (slot->state != CAL_DMA_COMPLETE) {
        return CAL_DMA_STATE;
    }

    slot->state = CAL_DMA_USER_OWNED;
    token->index = index;
    token->generation = slot->generation;
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_release(cal_dma_pool *pool, cal_dma_token token)
{
    cal_dma_slot *slot;
    cal_dma_status status = slot_for(pool, token, &slot);

    if (status) {
        return status;
    }
    if (slot->state == CAL_DMA_FREE) {
        return CAL_DMA_STALE;
    }
    if (slot->state != CAL_DMA_USER_OWNED) {
        return CAL_DMA_STATE;
    }

    slot->state = CAL_DMA_FREE;
    next_generation(slot);
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_cancel_owned(cal_dma_pool *pool, cal_dma_token token)
{
    cal_dma_slot *slot;
    cal_dma_status status = slot_for(pool, token, &slot);

    if (status) {
        return status;
    }
    if (slot->state != CAL_DMA_DRIVER_OWNED) {
        return CAL_DMA_STATE;
    }

    slot->state = CAL_DMA_FREE;
    next_generation(slot);
    return CAL_DMA_OK;
}

cal_dma_status cal_dma_pool_reset(cal_dma_pool *pool)
{
    size_t index;

    if (!pool || !pool->slots) {
        return CAL_DMA_NULL;
    }

    for (index = 0; index < pool->count; ++index) {
        if (pool->slots[index].state != CAL_DMA_FREE) {
            return CAL_DMA_BUSY;
        }
    }

    for (index = 0; index < pool->count; ++index) {
        next_generation(&pool->slots[index]);
        pool->slots[index].actual_bytes = 0;
        pool->slots[index].completion_error = 0;
        pool->slots[index].dma_address = 0;
    }
    return CAL_DMA_OK;
}
