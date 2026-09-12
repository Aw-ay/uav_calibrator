#include "frame_decode.h"

static uint16_t le16(const uint8_t *p) { return (uint16_t)p[0] | ((uint16_t)p[1] << 8); }
static uint32_t le32(const uint8_t *p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }
static uint64_t le64(const uint8_t *p) { return (uint64_t)le32(p) | ((uint64_t)le32(p + 4) << 32); }

uint32_t cal_crc32c(const void *data, size_t bytes) {
    const uint8_t *p = (const uint8_t *)data; uint32_t crc = UINT32_MAX;
    while (bytes--) { unsigned k; crc ^= *p++; for (k = 0; k < 8; ++k) crc = (crc >> 1) ^ ((crc & 1u) ? UINT32_C(0x82f63b78) : 0u); }
    return crc ^ UINT32_MAX;
}

static uint32_t header_crc(const uint8_t *p) {
    uint32_t crc = UINT32_MAX; size_t i;
    for (i = 0; i < FRAME_HEADER_BYTES; ++i) {
        uint8_t byte = (i >= FRAME_HEADER_CRC32C_OFFSET && i < FRAME_HEADER_CRC32C_OFFSET + 4u) ? 0u : p[i];
        unsigned k; crc ^= byte; for (k = 0; k < 8; ++k) crc = (crc >> 1) ^ ((crc & 1u) ? UINT32_C(0x82f63b78) : 0u);
    }
    return crc ^ UINT32_MAX;
}

cal_frame_status cal_frame_decode(const void *record, size_t available, size_t actual, cal_frame_view *out) {
    const uint8_t *p = (const uint8_t *)record; uint32_t payload, count, total, flags; size_t expected; const uint8_t *t;
    if (!p || !out) return CAL_FRAME_NULL;
    if (available < FRAME_HEADER_BYTES || actual < FRAME_HEADER_BYTES) return CAL_FRAME_SHORT;
    if (actual > available || actual > CAL_FRAME_MAX_RECORD_BYTES) return CAL_FRAME_LENGTH;
    if (le32(p + FRAME_MAGIC_OFFSET) != FRAME_MAGIC || le16(p + FRAME_SCHEMA_VERSION_OFFSET) != FRAME_ABI_VERSION || le16(p + FRAME_HEADER_BYTES_OFFSET) != FRAME_HEADER_BYTES) return CAL_FRAME_HEADER;
    payload = le32(p + FRAME_PAYLOAD_BYTES_OFFSET); count = le32(p + FRAME_SAMPLE_COUNT_OFFSET); total = le32(p + FRAME_RECORD_BYTES_OFFSET); flags = le32(p + FRAME_QUALITY_FLAGS_OFFSET);
    if (count == 0u || count > FRAME_MAX_SAMPLES || payload != count * FRAME_PAYLOAD_SAMPLE_BYTES) return CAL_FRAME_SAMPLES;
    expected = FRAME_HEADER_BYTES + (size_t)payload + ((flags & QUALITY_HAS_CRC_TRAILER) ? FRAME_TRAILER_BYTES : 0u);
    if (expected > CAL_FRAME_MAX_RECORD_BYTES || total != expected || actual != expected) return CAL_FRAME_LENGTH;
    if (!le32(p + FRAME_SAMPLE_STRIDE_TICKS_OFFSET) || !le32(p + FRAME_SAMPLE_RATE_NUM_OFFSET) || !le32(p + FRAME_SAMPLE_RATE_DEN_OFFSET)) return CAL_FRAME_GRID;
    if (le32(p + FRAME_RESERVED_OFFSET) != 0u) return CAL_FRAME_RESERVED;
    if (!(flags & QUALITY_CRC_DISABLED) && header_crc(p) != le32(p + FRAME_HEADER_CRC32C_OFFSET)) return CAL_FRAME_HEADER_CRC;
    if (flags & QUALITY_HAS_CRC_TRAILER) {
        t = p + FRAME_HEADER_BYTES + payload;
        if (le32(t) != FRAME_TRAILER_MAGIC || le32(t + 8) != payload || le32(t + 12) != 0u || le32(t + 4) != cal_crc32c(p + FRAME_HEADER_BYTES, payload)) return CAL_FRAME_TRAILER;
    }
    out->record=p; out->payload=p+FRAME_HEADER_BYTES; out->record_bytes=total; out->payload_bytes=payload; out->sample_count=count; out->quality_flags=flags;
    out->pulse_id=le64(p+FRAME_PULSE_ID_OFFSET); out->record_sequence=le64(p+FRAME_RECORD_SEQUENCE_OFFSET); out->gsc_first=le64(p+FRAME_GSC_FIRST_OFFSET);
    out->epoch_id=le32(p+FRAME_EPOCH_ID_OFFSET); out->config_id=le32(p+FRAME_CONFIG_ID_OFFSET); out->sample_stride_ticks=le32(p+FRAME_SAMPLE_STRIDE_TICKS_OFFSET); out->sample_rate_num=le32(p+FRAME_SAMPLE_RATE_NUM_OFFSET); out->sample_rate_den=le32(p+FRAME_SAMPLE_RATE_DEN_OFFSET);
    out->format_id=le16(p+FRAME_FORMAT_ID_OFFSET); out->range_id=p[FRAME_RANGE_ID_OFFSET]; out->channel_mask=p[FRAME_CHANNEL_MASK_OFFSET]; out->stream_group_id=p[FRAME_STREAM_GROUP_ID_OFFSET]; out->physical_adc_mask=p[FRAME_PHYSICAL_ADC_MASK_OFFSET]; out->source_role=p[FRAME_SOURCE_ROLE_OFFSET]; out->source_flags=p[FRAME_SOURCE_FLAGS_OFFSET];
    return CAL_FRAME_OK;
}

cal_frame_status cal_frame_sample(const cal_frame_view *f, uint32_t index, cal_iq16 *out) {
    const uint8_t *p; if (!f || !out) return CAL_FRAME_NULL; if (index >= f->sample_count) return CAL_FRAME_SAMPLES;
    p=f->payload+(size_t)index*FRAME_PAYLOAD_SAMPLE_BYTES; out->h_i=(int16_t)le16(p); out->h_q=(int16_t)le16(p+2); out->v_i=(int16_t)le16(p+4); out->v_q=(int16_t)le16(p+6); return CAL_FRAME_OK;
}

const char *cal_frame_status_string(cal_frame_status s) {
    static const char *const names[]={"ok","null argument","short header","record length","header identity","sample length","sample grid","reserved bytes","header CRC32C","trailer CRC32C"};
    return (unsigned)s < sizeof names/sizeof names[0] ? names[s] : "unknown";
}
