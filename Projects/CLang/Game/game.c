#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include "../HB128/hb128.h"
#include "assets/tiles_meta.h"

extern char getch();

extern void vb_handler();
extern unsigned char tileDef[PROJECT_TILE_COUNT*16];
extern unsigned char superTileDef[PROJECT_SUPERTILE_COUNT][SUPERTILE_GRID_HEIGHT][SUPERTILE_GRID_WIDTH];
extern unsigned char superTileMap[PROJECT_MAP_HEIGHT][PROJECT_MAP_WIDTH];
extern unsigned char spritePattern[2*2*8];

extern void renderViewAsm();

unsigned char scrBuf[32*PROJECT_MAP_HEIGHT*2];

unsigned char tileCombos[PROJECT_TILE_COUNT][PROJECT_TILE_COUNT];

unsigned char int_v, int_c;
unsigned char mapX,mapS;
unsigned char sprite_space;

int maxCombos,nameIdx;

extern unsigned char x_coord[], y_coord[];
char msg[] = "abcdefghijklmnopqrstuvwxtz012345";
unsigned char spr_x[32], spr_y[32], spr_pat[32], spr_col[32];
int spr_cycle;

void writeTileCombos() {
    int i,j,d,s;
    int pat;
    unsigned int shf,lhs,rhs,col;
    unsigned char *src1, *src2,*dst;

    for(j=0;j<PROJECT_TILE_COUNT;j++) {
        for(i=0;i<PROJECT_TILE_COUNT;i++) {
            pat=tileCombos[j][i];
            if(pat) {
                // Shifting 0 to 3, 2 pix at a time
                for(s=0;s<4;s++){
                    // LHS source
                    src1=&tileDef[i*8];
                    // RHS source
                    src2=&tileDef[j*8];
                    // This is where we'll write pattern data to in vram
                    dst=(unsigned char*)(0x0000+((pat+s)*8));
                    // 8 bytes of pattern data needs shifting
                    for(d=0;d<8;d++) {
                        // Assemble pre-shifted 16 bits
                        // LHS = src1, RHS = src2
                        lhs=*src1;
                        rhs=*src2;
                        shf=(lhs<<8) | (rhs);
                        // Now shift left 2*s
                        shf<<=(2*s);
                        // Take LHS byte only for vram patten
                        // three copies of the font in memory
                        dfcl_vpoke(dst,(shf>>8));
                        dfcl_vpoke(dst+0x800,(shf>>8));
                        dfcl_vpoke(dst+0x1000,(shf>>8));
                        // Now point to colour data in vram
                        dst+=0x2000;
                        // If lhs is no pixels, but rhs has pixels
                        // then fg colour comes from rhs, bg
                        // colour comes from lhs
                        col=*(src1+PROJECT_TILE_COUNT*8);
                        if(lhs==0) {
                            col=(col&0x0f)|(*(src2+PROJECT_TILE_COUNT*8)&0xf0);
                        }
                        // Three copies of colour data
                        dfcl_vpoke(dst,col);
                        dfcl_vpoke(dst+0x800,col);
                        dfcl_vpoke(dst+0x1000,col);
                        dst-=0x2000;
                        src1++; src2++; dst++;
                    }
                }
            }
        }
    }
}

// Each tile needs a scrolled version with each version an adjacent tile including self
// Scrolling is 2 pixels so need 4 versions of each tile including un-scrolled
// Total tiles needed t = PROJECT_TILE_COUNT*PROJECT_TILE_COUNT*4
// For 8 combos, thats 8*8*4=256

void processTileCombo(unsigned char t1, unsigned char t2) {
    if(tileCombos[t2][t1]==0) {
        tileCombos[t2][t1]=nameIdx;
        maxCombos++;
        nameIdx += 4;
    }
}

void initSuperTileDef() {
    int i,j,superIdx1,superIdx2;
    unsigned char tile1, tile2;

    for(j=0; i<PROJECT_TILE_COUNT; j++) {
        for(i=0; i<PROJECT_TILE_COUNT; i++) {
            tileCombos[j][i]=0;
        }
    }
    maxCombos=0;
    nameIdx=128;
    // Within each super tile, look at the tile combos
    // We only need to look within a super tile
    // So just consider the left side
    for (j=0; j<PROJECT_SUPERTILE_COUNT; j++) {
        // Top-left
        tile1 = superTileDef[j][0][0];
        tile2 = superTileDef[j][0][1];
        processTileCombo(tile1, tile2);
        // Bottom-left
        tile1 = superTileDef[j][1][0];
        tile2 = superTileDef[j][1][1];
        processTileCombo(tile1, tile2);
    }
    // Within the whole map, look at the tile overlap combos
    // We need to consider two adjacent tiles
    // Then tiles overlapping between the right of one and the left of the other
    for (j=0; j<PROJECT_MAP_HEIGHT; j++) {
        for(i=0; i<PROJECT_MAP_WIDTH-1;i++) {
            superIdx1=superTileMap[j][i];
            superIdx2=superTileMap[j][i+1];
            // Top-right tile 1, top left tile 2
            tile1 = superTileDef[superIdx1][0][1];
            tile2 = superTileDef[superIdx2][0][0];
            processTileCombo(tile1, tile2);
            // Bottom-right tile 1, bottom left tile 2
            tile1 = superTileDef[superIdx1][1][1];
            tile2 = superTileDef[superIdx2][1][0];
            processTileCombo(tile1, tile2);
        }
    }
}


void initScrBuf(unsigned char j) {
    int i;

    for (i=0; i<32*24; i++) {
        scrBuf[i]=j;
    }
}

void showStats() {
    int i,j,k;

    printf("  Max combos = %d  \r",maxCombos);
    printf("  Name idx = %d  \r", nameIdx);

    k=0;
    for(j=0;j<8;j++) {
        for(i=0;i<32;i++) {
            dfcl_plot(i,j+16,k++);
        }
    }
}

// Index into map, s=shift
void renderView(int idx, int s) {
    int i,j,t;
    unsigned char st1,st2,t1,t2;

    t=idx;
    idx>>=1;
    for(j=0;j<PROJECT_MAP_HEIGHT;j++) {
        for(i=0;i<16;i++) {
            // If idx is odd then right hand side is plotted first
            if(t&1) {
                st1=superTileMap[j][i+idx];
                st2=superTileMap[j][i+1+idx];
                // Left side is from st1 rhs and st2 lhs
                // Top
                t1 = superTileDef[st1][0][1];
                t2 = superTileDef[st2][0][0];
                dfcl_plot(i*2,j*2,tileCombos[t2][t1]+s);
                // Bottom
                t1 = superTileDef[st1][1][1];
                t2 = superTileDef[st2][1][0];
                dfcl_plot(i*2,j*2+1,tileCombos[t2][t1]+s);

                // Right side is from st2 lhs and rhs
                // Top
                t1 = superTileDef[st2][0][0];
                t2 = superTileDef[st2][0][1];
                dfcl_plot(i*2+1,j*2,tileCombos[t2][t1]+s);
                // Bottom
                t1 = superTileDef[st2][1][0];
                t2 = superTileDef[st2][1][1];
                dfcl_plot(i*2+1,j*2+1,tileCombos[t2][t1]+s);
                // Right side is from st1 and st2
            } else
            {
                st1=superTileMap[j][i+idx];
                st2=superTileMap[j][i+1+idx];
                // Left side is only from st1
                // Top
                t1 = superTileDef[st1][0][0];
                t2 = superTileDef[st1][0][1];
                dfcl_plot(i*2,j*2,tileCombos[t2][t1]+s);
                // Bottom
                t1 = superTileDef[st1][1][0];
                t2 = superTileDef[st1][1][1];
                dfcl_plot(i*2,j*2+1,tileCombos[t2][t1]+s);
                // Right side is from st1 and st2
                // Top
                t1 = superTileDef[st1][0][1];
                t2 = superTileDef[st2][0][0];
                dfcl_plot(i*2+1,j*2,tileCombos[t2][t1]+s);
                // Bottom
                t1 = superTileDef[st1][1][1];
                t2 = superTileDef[st2][1][0];
                dfcl_plot(i*2+1,j*2+1,tileCombos[t2][t1]+s);
            }
        }
    }
}


void init_spr() {
    int i;

    for(i=0; i<32; i++) {
        spr_x[i]=0;
        spr_y[i]=200;
        spr_pat[i]=msg[i];
        spr_pat[i]=0;
        spr_col[i]=(i*3)%14+2;
    }

    for(i=0; i<32; i+=2) {
        spr_pat[i]=0;
        spr_pat[i+1]=4;
    }

    for(i=0; i<64; i++) {
        dfcl_vpoke((unsigned char*)(0x1800+i),spritePattern[i]);
    }
}

void move_spr() {
    int j,s;

    j=spr_cycle;
    for(s=0; s<32; s+=2) {
        spr_x[s]=x_coord[j];
        spr_y[s]=y_coord[j];
        spr_x[s+1]=x_coord[j];
        spr_y[s+1]=y_coord[j];
        j+=sprite_space;
        if(j>255) {
            j-=255;
        }
    }
}
int main() {
    char k;
    unsigned char joy, z, del;
    int scroll, dx;

    dfcl_mode(0x2);
    dfcl_cursor(1);
    dfcl_colour(32,1,1);
    dfcl_vdp_setreg(1,0b11100010);  // Bit 1=sprites 16x16

    int_v=0;
    int_c=0;

    dfcl_vbint(vb_handler);

    k=0;
    joy=0;

   
    z=0;
    initScrBuf(0);
    initSuperTileDef();
    writeTileCombos();

//    showStats();
    init_spr();
    dfcl_wait(100);
    spr_cycle=0;
    scroll=0;
    dx=0;
    del=0;
    sprite_space=16;
    do {
        del++;
        if((del&7)==7) {
            joy=dfcl_stick(0xff);
            if(joy & 64) {
                dx--;
                if(dx<-8) dx=-8;
            }
            if(joy & 32) {
                dx++;
                if(dx>8) dx=8;
            }
            if(joy & 8) {
                sprite_space++;
                if(sprite_space>16) sprite_space=16;
            }
            if(joy & 16) {
                sprite_space--;
                if(sprite_space<4) sprite_space=4;
            }

        }

        if((del&3)==3) {
            move_spr();
            if(++spr_cycle>255) {
                spr_cycle-=255;
            }
        }

        scroll+=dx;
        if(scroll<0) {
            scroll += 1024;
        }
        if(scroll>1023) {
            scroll -= 1024;
        }
        mapX=scroll>>2;
        mapS=scroll&3;
        renderViewAsm();

        int_v=1;
        while(int_v) {}
    }while(!(joy&128));

    return 0xd010;
} 
