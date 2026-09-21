#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include "../HB128/hb128.h"

extern char getch();
extern void vb_handler();

unsigned char chan[3],ay[3],chan_spr[3];

unsigned char ay_i;

void ay_handler() {
    for(ay_i=0; ay_i<3; ay_i++) {
        if(chan_spr[ay_i]<150) {
            chan_spr[ay_i]++;
            dfcl_sprpos(ay_i, ay_i*10+20,chan_spr[ay_i]);
        }
    }
}

int main() {
    int i,j,s;
    char k;
    unsigned char sfx,joy;

    dfcl_mode(0x1);

    i=dfcl_ptload("ahatake.pt3",(unsigned char*)0x8000);

    // Channel indicators
    for(i=0; i<3; i++) {
        dfcl_sprnme(i,128);
        dfcl_sprcol(i,i*2+2);
        dfcl_sprpos(i, i*10+20,150);
        ay[i]=0;
        chan[i]=ay[i];
        chan_spr[i]=150-chan[i]*5;
    }
    dfcl_vbint(vb_handler);
    dfcl_ptinit((unsigned char*)0x8000,0);
    
    i=0;
    k=0;
    joy=0;
    while(1) {
        for(i=0; i<3; i++) {
            if(chan[i]!=ay[i]) {
                if(ay[i]>chan[i]) {
                    chan[i]=ay[i];
                    chan_spr[i]=150-chan[i]*5;
                }
            }
        }
        if(dfcl_stick(0x80)) {
            if(!joy) {
                joy=1;
                sfx ^= 1;
                if(sfx)
                    dfcl_ptrun(1);
                else
                    dfcl_ptrun(0);
            }
        } else {
            joy=0;
        }
    }
    


//    dfcl_sndconfig(0,0,0,0);

    return 0xd010;
}