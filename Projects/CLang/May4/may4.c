#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include "../HB128/hb128.h"

extern char getch();

extern unsigned char star[];
extern unsigned char x_coord[], y_coord[];

char msg[] = "MAY THE FOURTH BE WITH YOU      ";
unsigned char sprused[32];

unsigned char int_v, int_c;

void vb_handler() {
    if(int_v<16) {
        if(int_c) {
            int_c--;
        } else {
            int_c=3;
            dfcl_sprnme(31,int_v);
            int_v++;
        }
    }
}

int main() {
    int i,j,s;
    char k;
    unsigned char sfx,joy;

    dfcl_mode(0x11);
    dfcl_colour(32,1,1);

    i=dfcl_ptload("starwars.pt3",(unsigned char*)0x8000);
    i=dfcl_vload("may4",0);

    for(i=0; i<32; i++) {
        dfcl_sprnme(i,msg[i]);
        dfcl_sprpos(i,0,200);
//        dfcl_sprcol(i,(i%14)+2);
        dfcl_sprcol(i,15);
        if(msg[i]==' ') {
            sprused[i]=0;
        }
        else {
            sprused[i]=1;
        }
    }

    for(i=0; i<16; i++) {
        dfcl_sprpat(i,&star[(i)*8]);
    }

    dfcl_sndconfig(7,0,0,0);
    for(j=100; j<2000; j+=15) {
        dfcl_sndchannel(1,10,j);
        dfcl_sndchannel(2,10,j+4);
        dfcl_wait(1);
    }
    dfcl_wait(300);

    // Star
    dfcl_sprnme(31,0);
    dfcl_sprpos(31,99,60);
    dfcl_sprcol(31,15);
    int_c=0;
    int_v=0;
    dfcl_vbint(vb_handler);
    for(i=15; i>=0; i--) {
        dfcl_sndchannel(3,i,35);
        dfcl_wait(3);
    }
    dfcl_wait(100);

    for(i=10; i>=0; i--) {
        dfcl_sndchannel(1,i,j);
        dfcl_sndchannel(2,i,j+4);
        dfcl_wait(20);
    }

    sfx=1;
    dfcl_ptinit((unsigned char*)0x8000,0);
    
    i=0;
    k=0;
    joy=0;
    while(1) {
        j=i;
        for(s=0; s<32; s++) {
            if(sprused[s]) {
//                if(y_coord[s]>120)
//                    dfcl_sprpos(s,0, 200);
//                else
                    dfcl_sprpos(s,x_coord[j], y_coord[j]);
            }
            j+=6;
            if(j>255) {
                j-=255;
            }
        }
        dfcl_wait(2);
        i--;
        if(i<0) i=255;
        if(!(i%64)) {
            k++;
            if(k>5) k=0;
            switch (k) {
                case 0: dfcl_sprpos(31,10,10); break;
                case 1: dfcl_sprpos(31,200,180); break;
                case 2: dfcl_sprpos(31,50,120); break;
                case 3: dfcl_sprpos(31,100,80); break;
                case 4: dfcl_sprpos(31,180,20); break;
                default: dfcl_sprpos(31,80,50);
            }
            int_v=0;
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