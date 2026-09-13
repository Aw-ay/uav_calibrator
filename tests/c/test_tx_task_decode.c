#include "unified_event_reader.h"
#include <assert.h>
#include <stdio.h>
#ifdef _WIN32
#include <windows.h>
#endif
int main(int argc,char **argv){
#ifdef _WIN32
 SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX);
#endif
 assert(argc==2);FILE *f=fopen(argv[1],"r");assert(f);unsigned rows=0,word;uint8_t bytes[64];
 while(fscanf(f,"%x",&word)==1){
  for(unsigned w=0;w<16;w++){if(w)assert(fscanf(f,"%x",&word)==1);for(unsigned b=0;b<4;b++)bytes[w*4+b]=(uint8_t)(word>>(8*b));}
  if(rows==0||rows==3){cal_replay_identity e;assert(cal_replay_identity_decode(bytes,64,&e)==CAL_RI_OK);
   assert(e.token==(rows==0?1u:3u)&&e.task_id==UINT64_C(0xfedcba9876543210));
  }else {cal_tx_lifecycle_event e;assert(cal_tx_lifecycle_decode(bytes,64,&e)==CAL_TX_OK);
   assert(e.token==(rows==1?1u:rows==2?2u:3u)&&e.source==(rows==2?1u:3u));
   assert(e.reason==(rows==4?4u:0u));
   if(rows==4){bytes[8]=1;assert(cal_tx_lifecycle_decode(bytes,64,&e)==CAL_TX_VALUE);}
  }rows++;
 }
 fclose(f);assert(rows==5);puts("PASS shared TX lifecycle C decode identities replay abort and shared tokens");return 0;
}
