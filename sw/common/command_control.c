#include "command_control.h"
static uint32_t crc_word(uint32_t crc,uint32_t word){unsigned b;for(b=0;b<32;b++){crc=(crc>>1)^(((crc^word)&1u)?0x82f63b78u:0u);word>>=1;}return crc;}
uint32_t cal_command_crc(uint16_t op,uint16_t words,uint32_t seq,const uint32_t *p){
 uint32_t crc=crc_word(crc_word(UINT32_MAX,((uint32_t)words<<16)|op),seq);unsigned i;
 for(i=0;i<words;i++)crc=crc_word(crc,p[i]);
 return ~crc;
}
static int valid_io(const cal_command_io *io){return io&&io->read32&&io->write32;}
cal_command_status cal_command_begin(const cal_command_io *io,uint16_t op,uint16_t words,uint32_t seq,const uint32_t *p){
 uint32_t status;unsigned i;
 if(!valid_io(io)||words>CAL_GW_WORDS||(words&&!p))return CAL_CMD_ARGUMENT;
 if(io->read32(io->context,CAL_GW_STATUS,&status))return CAL_CMD_IO;
 if(status&1u)return CAL_CMD_BUSY;
 if(io->write32(io->context,CAL_GW_STATUS,2))return CAL_CMD_IO;
 for(i=0;i<words;i++)if(io->write32(io->context,CAL_GW_PAYLOAD+4*i,p[i]))return CAL_CMD_IO;
 if(io->write32(io->context,CAL_GW_OP_LENGTH,((uint32_t)words<<16)|op)||
    io->write32(io->context,CAL_GW_SEQUENCE,seq)||
    io->write32(io->context,CAL_GW_CRC32C,cal_command_crc(op,words,seq,p)))return CAL_CMD_IO;
 if(io->write32(io->context,CAL_GW_SUBMIT,1))return CAL_CMD_SUBMIT_UNKNOWN;
 return CAL_CMD_OK;
}
cal_command_status cal_command_poll(const cal_command_io *io,uint32_t seq,uint32_t *p,uint16_t capacity,cal_command_result *result){
 uint32_t status,done,words;unsigned i;
 if(!valid_io(io)||!result||(capacity&&!p))return CAL_CMD_ARGUMENT;
 if(io->read32(io->context,CAL_GW_STATUS,&status))return CAL_CMD_IO;
 if((status&1u)||!(status&2u))return CAL_CMD_PENDING;
 if(io->read32(io->context,CAL_GW_DONE_SEQUENCE,&done)||io->read32(io->context,CAL_GW_RESULT_LENGTH,&words))return CAL_CMD_IO;
 if(done!=seq)return CAL_CMD_SEQUENCE;
 if(words>CAL_GW_WORDS)return CAL_CMD_PROTOCOL;
 if(words>capacity)return CAL_CMD_CAPACITY;
 for(i=0;i<words;i++)if(io->read32(io->context,CAL_GW_RESULT+4*i,&p[i]))return CAL_CMD_IO;
 result->words=(uint16_t)words;result->code=(uint8_t)(status>>8);
 return CAL_CMD_OK;
}

cal_command_status cal_command_irq_enable(const cal_command_io *io,uint32_t mask){
 if(!valid_io(io)||(mask&~(CAL_GW_IRQ_COMMAND_DONE|CAL_GW_IRQ_PDW_AVAILABLE|CAL_GW_IRQ_SOURCE_EVENT_AVAILABLE)))return CAL_CMD_ARGUMENT;
 return io->write32(io->context,CAL_GW_IRQ_ENABLE,mask)?CAL_CMD_IO:CAL_CMD_OK;
}
cal_command_status cal_command_irq_status(const cal_command_io *io,uint32_t *out){
 uint32_t value;
 if(!valid_io(io)||!out)return CAL_CMD_ARGUMENT;
 if(io->read32(io->context,CAL_GW_IRQ_STATUS,&value))return CAL_CMD_IO;
 if(value&~(CAL_GW_IRQ_COMMAND_DONE|CAL_GW_IRQ_PDW_AVAILABLE|CAL_GW_IRQ_SOURCE_EVENT_AVAILABLE))return CAL_CMD_PROTOCOL;
 *out=value;return CAL_CMD_OK;
}
