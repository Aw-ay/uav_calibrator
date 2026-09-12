#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif
#include "frame_decode.h"
#include "dma_slots.h"

static int frame_test(void) {
    unsigned char *b = malloc(CAL_FRAME_MAX_RECORD_BYTES + 1u);
    size_t n = fread(b, 1, CAL_FRAME_MAX_RECORD_BYTES + 1u, stdin);
    cal_frame_view f;
    cal_frame_status s = cal_frame_decode(b, n, n, &f);
    if (s != CAL_FRAME_OK) { fprintf(stderr, "%s", cal_frame_status_string(s)); free(b); return 1; }
    cal_iq16 x;
    if (cal_frame_sample(&f, f.sample_count - 1u, &x) != CAL_FRAME_OK) return 2;
    printf("%u %u %d %d %llu", f.sample_count, f.record_bytes, x.v_i, x.v_q,
           (unsigned long long)f.pulse_id);
    free(b); return 0;
}

static int slots_test(void) {
    cal_dma_slot slots[2]; cal_dma_pool pool; cal_dma_token a, b;
    if (cal_dma_pool_init(&pool, slots, 2, 262144) != CAL_DMA_OK) return 10;
    if (cal_dma_claim(&pool, 0, UINT64_C(0x100000), &a) != CAL_DMA_OK) return 11;
    if (cal_dma_activate(&pool, a) != CAL_DMA_OK) return 12;
    if (cal_dma_complete(&pool, a, 131216, 0) != CAL_DMA_OK) return 13;
    if (cal_dma_acquire_complete(&pool, 0, &b) != CAL_DMA_OK || b.generation != a.generation) return 14;
    if (cal_dma_release(&pool, b) != CAL_DMA_OK) return 15;
    if (cal_dma_release(&pool, b) != CAL_DMA_STALE) return 16;
    if (cal_dma_claim(&pool, 0, UINT64_C(0x100001), &a) != CAL_DMA_ADDRESS) return 17;
    if (cal_dma_claim(&pool, 0, UINT64_C(1) << 40, &a) != CAL_DMA_ADDRESS) return 18;
    if (cal_dma_claim(&pool, 0, (UINT64_C(1) << 40) - 64u, &a) != CAL_DMA_ADDRESS) return 24;
    if (cal_dma_claim(&pool, 0, UINT64_C(0x100000), &a) != CAL_DMA_OK) return 19;
    if (cal_dma_pool_reset(&pool) != CAL_DMA_BUSY) return 20;
    if (cal_dma_cancel_owned(&pool, a) != CAL_DMA_OK) return 21;
    if (cal_dma_pool_reset(&pool) != CAL_DMA_OK) return 22;
    if (cal_dma_claim(&pool, 2, UINT64_C(0x100000), &a) != CAL_DMA_BOUNDS) return 23;
    return 0;
}

static int occupy(cal_dma_pool *pool, cal_dma_slot slots[2], cal_dma_state state) {
    cal_dma_token token, user;
    if (cal_dma_pool_init(pool, slots, 2, 256) != CAL_DMA_OK) return 1;
    if (cal_dma_claim(pool, 0, UINT64_C(0x100000), &token) != CAL_DMA_OK) return 2;
    if (state >= CAL_DMA_ACTIVE && cal_dma_activate(pool, token) != CAL_DMA_OK) return 3;
    if (state >= CAL_DMA_COMPLETE && cal_dma_complete(pool, token, 128, 0) != CAL_DMA_OK) return 4;
    if (state >= CAL_DMA_USER_OWNED && cal_dma_acquire_complete(pool, 0, &user) != CAL_DMA_OK) return 5;
    return 0;
}

static int overflow_regression(void) {
    cal_dma_slot one; cal_dma_pool pool;
    size_t impossible = SIZE_MAX / sizeof(cal_dma_slot) + 1u;
    if (cal_dma_pool_init(&pool, &one, impossible, 256) != CAL_DMA_BOUNDS) return 30;
    return 0;
}

static int overlap_regression(void) {
    cal_dma_slot slots[2]; cal_dma_pool pool; cal_dma_token token; cal_dma_state state;
    for (state = CAL_DMA_DRIVER_OWNED; state <= CAL_DMA_USER_OWNED; state = (cal_dma_state)(state + 1)) {
        if (occupy(&pool, slots, state)) return 31;
        if (cal_dma_claim(&pool, 1, UINT64_C(0x100000), &token) != CAL_DMA_ADDRESS) return 32;
        if (cal_dma_claim(&pool, 1, UINT64_C(0x100040), &token) != CAL_DMA_ADDRESS) return 33;
        if (cal_dma_claim(&pool, 1, UINT64_C(0x0fff80), &token) != CAL_DMA_ADDRESS) return 34;
        if (cal_dma_claim(&pool, 1, UINT64_C(0x100100), &token) != CAL_DMA_OK) return 35;
    }
    return 0;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(_fileno(stdin), _O_BINARY);
#endif
    if (argc != 2) return 99;
    if (!strcmp(argv[1], "frame") || !strcmp(argv[1], "frame-extra")) return frame_test();
    if (!strcmp(argv[1], "slots")) return slots_test();
    if (!strcmp(argv[1], "overlap-regression")) return overlap_regression();
    if (!strcmp(argv[1], "overflow-regression")) return overflow_regression();
    return 98;
}
