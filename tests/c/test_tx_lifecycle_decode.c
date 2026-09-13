#include "tx_lifecycle_decode.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#endif
int main(int argc,char **argv){
#ifdef _WIN32
 SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX);
#endif
 assert(argc==2);FILE *f=fopen(argv[1],"r");assert(f);unsigned word;uint8_t bytes[64];unsigned rows=0;
 cal_tx_lifecycle_event event={0},before;
 while(fscanf(f,"%x",&word)==1){
  for(unsigned w=0;w<16;w++){if(w)assert(fscanf(f,"%x",&word)==1);for(unsigned b=0;b<4;b++)bytes[w*4+b]=(uint8_t)(word>>(8*b));}
  assert(cal_tx_lifecycle_decode(bytes,64,&event)==CAL_TX_OK);rows++;assert(event.token==rows&&event.source==1&&event.command_sequence==7&&event.config_id==9);
  assert(event.flags==(rows==1?3u:rows==2?7u:1u));assert(event.reason==(rows==2?2u:0u));
  before=event;bytes[56]=1;assert(cal_tx_lifecycle_decode(bytes,64,&event)==CAL_TX_RESERVED&&!memcmp(&event,&before,sizeof event));bytes[56]=0;
  bytes[4]=0;assert(cal_tx_lifecycle_decode(bytes,64,&event)==CAL_TX_VALUE);bytes[4]=0x80;assert(cal_tx_lifecycle_decode(bytes,64,&event)==CAL_TX_SCHEMA);
 }
 fclose(f);assert(rows==3);assert(cal_tx_lifecycle_decode(NULL,64,&event)==CAL_TX_ARGUMENT);assert(cal_tx_lifecycle_decode(bytes,63,&event)==CAL_TX_SHORT);
 puts("PASS TX lifecycle C decoder actual RTL records and invalid flags/reserved/short");return 0;
}
