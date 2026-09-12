#include "fault_event_decode.h"
#include "event_control.h"
#include <assert.h>
#include <stdio.h>
static void bytes(const unsigned *w,unsigned char *b){for(unsigned i=0;i<16;i++)for(unsigned j=0;j<4;j++)b[i*4+j]=(unsigned char)(w[i]>>(8*j));}
int main(int argc,char **argv){
 unsigned w[16]={0x40001,0,3,0,0x30001,3,7,0,0x1c,0x2c,28,0,0,0,0,0};unsigned char b[64];cal_fault_event e={0};
 bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_OK&&e.occurrences==3&&e.config_id==7&&e.observation_gsc==28);
 assert(cal_fault_event_decode(b,63,&e)==CAL_FE_SHORT);
 w[1]=2;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_SCHEMA&&e.occurrences==3);
 w[1]=1;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_VALUE);w[2]=0xffffffff;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_OK);
 w[1]=0;w[2]=0;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_VALUE);w[2]=1;
 w[3]=1;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_RESERVED);w[3]=0;w[15]=1;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_RESERVED);w[15]=0;
 w[4]=0;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_SCHEMA);w[4]=0x30001;
 w[5]=0;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_VALUE);w[6]=0;w[10]=0;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_OK);
 w[7]=5;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_VALUE);w[7]=0;
 w[8]=1024;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_VALUE);w[8]=0;
 w[9]=64;bytes(w,b);assert(cal_fault_event_decode(b,64,&e)==CAL_FE_VALUE);
 assert(argc==2);FILE *f=fopen(argv[1],"r");assert(f);unsigned faults=0,normals=0,rows=0;
 while(fscanf(f,"%x",&w[0])==1){for(unsigned i=1;i<16;i++)assert(fscanf(f,"%x",&w[i])==1);bytes(w,b);rows++;
  if(w[0]==0x10001){cal_event pdw;assert(cal_event_decode(b,64,&pdw)==CAL_EVENT_OK);normals++;assert(pdw.pulse_id==normals);}
  else {assert(cal_fault_event_decode(b,64,&e)==CAL_FE_OK);assert(e.flags==0&&e.snapshot_flags==3&&e.config_id==faults+1&&e.observation_gsc==(faults+1)*4&&e.rf_state==0&&e.normalized_inputs==0x1c&&e.logical_outputs==0x2c);faults+=e.occurrences;}
 }
 fclose(f);assert(faults==40&&normals==5);printf("PASS fault EVENT C validation actual RTL rows=%u faults=%u normals=%u\n",rows,faults,normals);return 0;
}
