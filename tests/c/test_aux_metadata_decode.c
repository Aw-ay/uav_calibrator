#include "aux_metadata_decode.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv){
 unsigned char p[96],bad[96];cal_aux_metadata e,saved;FILE *f;
 assert(argc==2);f=fopen(argv[1],"rb");assert(f);assert(fread(p,1,96,f)==96);fclose(f);
 assert(cal_aux_metadata_decode(p,96,&e)==CAL_AM_OK);
 assert(e.tx_token==UINT64_C(0xfedcba9876543210)&&e.capture_id==UINT64_C(0x123456789abcdef0));
 assert(e.owner_epoch==UINT64_C(0xabcdef0123456789)&&e.generation==UINT64_C(0x9876543210abcdef));
 assert(e.metadata_id==0xfedcba98u&&e.epoch_id==9&&e.sample_count==16384&&e.start_seq==1234&&e.start_gsc==5678);
 assert(e.source_epoch==7&&e.h_calibration_id==11&&e.v_calibration_id==12&&e.config_id==13&&e.fir_id==14&&e.source_role==3&&e.bank==2&&e.status==0);
 saved=e;
 assert(cal_aux_metadata_decode(p,95,&e)==CAL_AM_SHORT);assert(memcmp(&e,&saved,sizeof e)==0);
 assert(cal_aux_metadata_decode(NULL,96,&e)==CAL_AM_ARGUMENT);assert(cal_aux_metadata_decode(p,96,NULL)==CAL_AM_ARGUMENT);
 for(int i=0;i<8;i++){memcpy(bad,p,96);bad[i]^=128;assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_SCHEMA);}
 for(int i=91;i<96;i++){memcpy(bad,p,96);bad[i]=1;assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_RESERVED);}
 memcpy(bad,p,96);bad[88]=1;assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_VALUE);
 memcpy(bad,p,96);bad[89]=4;assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_VALUE);
 memcpy(bad,p,96);bad[90]=32;assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_VALUE);
 memcpy(bad,p,96);memset(bad+8,0,4);assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_VALUE);
 memcpy(bad,p,96);memset(bad+16,0,8);assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_VALUE);
 memcpy(bad,p,96);memset(bad+84,0,4);assert(cal_aux_metadata_decode(bad,96,&e)==CAL_AM_VALUE);
 assert(memcmp(&e,&saved,sizeof e)==0);
 puts("PASS AUX metadata C decode RTL bytes, full identity, malformed input and transactional output");return 0;
}
