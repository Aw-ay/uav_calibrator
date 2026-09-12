#ifndef CAL_COMMAND_CONTROL_H
#define CAL_COMMAND_CONTROL_H
#include <stdint.h>
#include "command_gateway.h"
/* Caller serializes this gateway across all threads/cores. Callbacks perform
 * ordered device MMIO relative to the gateway's AXI aperture, returning 0 on success.
 * An ambiguous submit must be reconciled with poll; never automatically resubmit. */
typedef struct {void *context;int (*read32)(void *,uint32_t,uint32_t *);int (*write32)(void *,uint32_t,uint32_t);} cal_command_io;
typedef enum {CAL_CMD_OK=0,CAL_CMD_PENDING,CAL_CMD_BUSY,CAL_CMD_ARGUMENT,CAL_CMD_IO,CAL_CMD_SUBMIT_UNKNOWN,CAL_CMD_SEQUENCE,CAL_CMD_CAPACITY,CAL_CMD_PROTOCOL} cal_command_status;
typedef struct {uint8_t code;uint16_t words;} cal_command_result;
uint32_t cal_command_crc(uint16_t opcode,uint16_t words,uint32_t sequence,const uint32_t *payload);
cal_command_status cal_command_begin(const cal_command_io *,uint16_t opcode,uint16_t words,uint32_t sequence,const uint32_t *payload);
cal_command_status cal_command_poll(const cal_command_io *,uint32_t sequence,uint32_t *payload,uint16_t capacity,cal_command_result *result);
/* IRQ status is raw (unmasked). PDW is a level: drain via exact-token POP;
 * STATUS=2 acknowledges command DONE only. Serialize with other gateway users. */
cal_command_status cal_command_irq_enable(const cal_command_io *,uint32_t mask);
cal_command_status cal_command_irq_status(const cal_command_io *,uint32_t *raw_status);
#endif
