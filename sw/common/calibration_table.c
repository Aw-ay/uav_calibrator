#include "calibration_table.h"
#include "frame_decode.h"
#include <string.h>
static uint32_t get32(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint64_t get64(const uint8_t *p){return get32(p)|((uint64_t)get32(p+4)<<32);}
static int32_t signed_bits(const uint8_t *p,unsigned bit,unsigned width){
 uint32_t v=0;unsigned i;for(i=0;i<width;i++)v|=(uint32_t)((p[(bit+i)/8]>>((bit+i)%8))&1u)<<i;
 return (int32_t)((v&(UINT32_C(1)<<(width-1)))?(int64_t)v-(INT64_C(1)<<width):(int64_t)v);
}
cal_table_status cal_table_validate(const void *bytes,size_t size,const cal_table_expect *expected,cal_table_view *out){
 const uint8_t *p=(const uint8_t *)bytes,*payload;uint8_t copy[CAL_TABLE_BYTES];unsigned i;cal_table_view v;
 if(out)memset(out,0,sizeof *out);
 if(!p||!expected||!out)return CAL_TABLE_ARGUMENT;
 if(size!=CAL_TABLE_BYTES)return CAL_TABLE_SIZE;
 if(get32(p+CAL_TABLE_MAGIC_OFFSET)!=CAL_TABLE_MAGIC||get32(p+CAL_TABLE_FORMAT_VERSION_OFFSET)!=CAL_TABLE_VERSION)return CAL_TABLE_SCHEMA;
 for(i=0;i<CAL_TABLE_RESERVED_HEADER_BYTES;i++)if(p[CAL_TABLE_RESERVED_HEADER_OFFSET+i])return CAL_TABLE_RESERVED;
 for(i=0;i<CAL_TABLE_RESERVED_TAIL_BYTES;i++)if(p[CAL_TABLE_RESERVED_TAIL_OFFSET+i])return CAL_TABLE_RESERVED;
 payload=p+CAL_TABLE_PAYLOAD_OFFSET;
 for(i=CAL_PAYLOAD_RESERVED_ZERO_BIT;i<CAL_PAYLOAD_RESERVED_ZERO_BIT+CAL_PAYLOAD_RESERVED_ZERO_WIDTH;i++)if((payload[i/8]>>(i%8))&1u)return CAL_TABLE_RESERVED;
 if(cal_crc32c(payload,CAL_TABLE_PAYLOAD_BYTES)!=get32(p+CAL_TABLE_PAYLOAD_CRC32C_OFFSET))return CAL_TABLE_CRC;
 memcpy(copy,p,sizeof copy);memset(copy+CAL_TABLE_RECORD_CRC32C_OFFSET,0,CAL_TABLE_RECORD_CRC32C_BYTES);
 if(cal_crc32c(copy,sizeof copy)!=get32(p+CAL_TABLE_RECORD_CRC32C_OFFSET))return CAL_TABLE_CRC;
 memset(&v,0,sizeof v);v.cal_id=get32(p+CAL_TABLE_CAL_ID_OFFSET);v.generation=get64(p+CAL_TABLE_GENERATION_OFFSET);
 v.direction=get32(p+CAL_TABLE_DIRECTION_OFFSET);v.logical_channel=get32(p+CAL_TABLE_LOGICAL_CHANNEL_OFFSET);v.reference_plane_id=get32(p+CAL_TABLE_REFERENCE_PLANE_ID_OFFSET);
 v.valid_from=get64(p+CAL_TABLE_VALID_FROM_OFFSET);v.valid_until=get64(p+CAL_TABLE_VALID_UNTIL_OFFSET);v.binding_id=get64(p+CAL_TABLE_BINDING_ID_OFFSET);
 if(!v.cal_id||!v.generation||!v.reference_plane_id||v.direction>1||v.logical_channel>7||
    v.cal_id!=expected->cal_id||v.generation!=expected->generation||v.direction!=expected->direction||v.logical_channel!=expected->logical_channel||v.reference_plane_id!=expected->reference_plane_id)return CAL_TABLE_CONTEXT;
 if(v.valid_until<=v.valid_from||expected->now_gsc<v.valid_from||expected->now_gsc>=v.valid_until)return CAL_TABLE_EXPIRED;
 if(get32(p+CAL_TABLE_VALID_OFFSET)!=1)return CAL_TABLE_DISABLED;
 v.gain_i=signed_bits(payload,CAL_PAYLOAD_GAIN_I_BIT,CAL_PAYLOAD_GAIN_I_WIDTH);
 v.gain_q=signed_bits(payload,CAL_PAYLOAD_GAIN_Q_BIT,CAL_PAYLOAD_GAIN_Q_WIDTH);
 v.dc_i=(int16_t)signed_bits(payload,CAL_PAYLOAD_DC_I_BIT,CAL_PAYLOAD_DC_I_WIDTH);
 v.dc_q=(int16_t)signed_bits(payload,CAL_PAYLOAD_DC_Q_BIT,CAL_PAYLOAD_DC_Q_WIDTH);
 v.logical_valid=1;*out=v;
 if(!expected->production_binding_valid||!v.binding_id||!expected->binding_id)return CAL_TABLE_UNBOUND;
 if(v.binding_id!=expected->binding_id){out->logical_valid=0;return CAL_TABLE_CONTEXT;}
 out->calibration_valid=1;return CAL_TABLE_OK;
}
