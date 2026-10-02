/* Counter-only SDT BSP application. No RFDC/PA enable writes. */
#include "sg_counter_rx.h"
#include "xparameters.h"
#include "xinterrupt_wrap.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xiltimer.h"
#ifndef SDT
#error Build this entry point against the generated 2025.2 SDT counter BSP
#endif
static cal_sg_counter_rx receiver;
static uint64_t ticks(void){XTime t;XTime_GetTime(&t);return (uint64_t)t;}
int main(void){
 static const uint32_t lengths[]={1,17,257,131216,262144};
 XAxiDma_Config *cfg=XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
 Xil_ICacheEnable();Xil_DCacheEnable();
 if(XPAR_XAXIDMA_0_BASEADDR!=0xa0040000u||XPAR_XGPIO_0_BASEADDR!=0xa0050000u||!cfg){xil_printf("COUNTER_BINDING_FAIL\r\n");return 1;}
 if(cal_sg_counter_init(&receiver,cfg,XPAR_XGPIO_0_BASEADDR,5u*(uint64_t)COUNTS_PER_SECOND,ticks)){xil_printf("COUNTER_INIT_FAIL\r\n");return 1;}
 if(XSetupInterruptSystem(&receiver,cal_sg_counter_irq,cfg->IntrId[cfg->HasMm2S ? 1 : 0],cfg->IntrParent,XINTERRUPT_DEFAULT_PRIORITY)!=XST_SUCCESS){xil_printf("COUNTER_IRQ_BIND_FAIL\r\n");return 1;}
 for(unsigned repeat=0;repeat<16;repeat++)for(unsigned i=0;i<sizeof lengths/sizeof lengths[0];i++){
  int rc;if(cal_sg_counter_start(&receiver,lengths[i]))return 1;
  do{rc=cal_sg_counter_poll(&receiver);}while(rc==0);
  if(rc<0){xil_printf("COUNTER_FAIL expected=%u actual=%u irq=%u error=%x; slots quarantined\r\n",receiver.expected,receiver.actual,receiver.irq_count,receiver.irq_error);return 1;}
  xil_printf("COUNTER_RX actual=%u irq=%u returned=%u\r\n",receiver.actual,receiver.irq_count,receiver.completed);
 }
 receiver.control|=2;Xil_Out32(receiver.control_base,receiver.control);
 xil_printf("COUNTER_TEST_PASS packets=%u RF_NOT_CONNECTED\r\n",receiver.completed);return 0;
}
