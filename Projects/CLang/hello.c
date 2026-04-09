#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include "HB128/hb128.h"

extern char getch();

unsigned char pattern[] = {
    0b00011000,
    0b00011000,
    0b00111100,
    0b10111101,
    0b10111101,
    0b11111111,
    0b11111111,
    0b01111110
};

int main() {
    int i;

    dfcl_mode(2);
    dfcl_colour(32,1,6);

    printf("Version 3\r");

    printf("Trying to load ahatake.pt3\r");

    i=dfcl_chdir("/demos/pt3");
    i=dfcl_ptload("ahatake.pt3",(unsigned char*)0x8000);

    dfcl_ptinit((unsigned char*)0x8000,0);

    dfcl_sprpat(0,pattern);
    dfcl_sprpos(0,100,100);
    dfcl_sprcol(0,4);
    dfcl_sprnme(0,0);

    printf("Trying to load font\r");
    i=dfcl_chdir("/font");
    i=dfcl_font("chrome.f00");
    printf("Font status = %x\r",i);
    for(i=0; i<100; i++) printf("The quick brown fox %d",i);
    dfcl_mode(0x61);
    i=dfcl_chdir("/data/image");
    i=dfcl_vload("snowman.vim",0);

    return 0xd010;
}