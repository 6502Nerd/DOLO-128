#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include "../HB128/hb128.h"
#include "assets/tiles_meta.h"

#define VBDELAY 1
#define FOES 14

extern char getch();

extern void vb_handler();
extern void move_spr();
extern void move_player();
extern void move_laser();
extern void spr_to_buf();

extern unsigned char tileDef[PROJECT_TILE_COUNT*16];
extern unsigned char superTileDef[PROJECT_SUPERTILE_COUNT][SUPERTILE_GRID_HEIGHT][SUPERTILE_GRID_WIDTH];
extern unsigned char superTileMap[PROJECT_MAP_HEIGHT][PROJECT_MAP_WIDTH];
extern unsigned char spritePattern[2*2*8];
extern unsigned char starfield[PROJECT_MAP_HEIGHT*2][32];

extern void renderViewAsm();

unsigned char scrBuf[32*PROJECT_MAP_HEIGHT*2];

unsigned char tileCombos[16][16];
unsigned char tileHit[256];

unsigned char int_delay,int_c;
unsigned int int_invoked,int_render,int_sprite;
unsigned char mapX,mapS;
unsigned char sprite_space;

signed char p_dx,p_dy,p_fx,p_fy,p_ddx,p_ddy,p_vy,p_vx;
int p_ex,p_ey;
unsigned char p_x,p_y,p_spr,p_hit;
int scroll;

int maxCombos,nameIdx;

extern unsigned char x_coord[], y_coord[];

unsigned char staridxl[128],staridxh[128],staryoff[128];
unsigned char starpat[128],maxstars;

unsigned char spr_x[32], spr_y[32], spr_pat[32], spr_col[32];
unsigned char sprb_x[32], sprb_y[32], sprb_pat[32], sprb_col[32];
char laser_x[8],laser_y[8],laser_dx[8],laser_pat[8],laser_ptrl[8],laser_ptrh[8];
int spr_cycle;

unsigned char foe_xl[FOES],foe_xh[FOES],foe_y[FOES];
unsigned char foe_pat1[FOES],foe_pat2[FOES],foe_col1[FOES],foe_col2[FOES];
unsigned char foe_data1[FOES],foe_data2[FOES],foe_counter[FOES];
unsigned char foe_state[FOES],foe_vecl[FOES],foe_vech[FOES];
extern void move_foes();
extern void foe_simple();
extern void foe_static();


void writeNormalTiles() {
    int i;
    unsigned char *src1,*dst,data;

    src1=&tileDef[16*8];                    // Max 16 tiles in supertiles
    dst=(unsigned char*)(0x0000);           // Start at low 32 chars
    for(i=(8*16);i<(8*PROJECT_TILE_COUNT);i++) {
        data=*src1;
        dfcl_vpoke(dst,data);
        dfcl_vpoke(dst+0x800,data);
        dfcl_vpoke(dst+0x1000,data);
        dst+=0x2000;
        data=*(src1+PROJECT_TILE_COUNT*8);
        dfcl_vpoke(dst,data);
        dfcl_vpoke(dst+0x800,data);
        dfcl_vpoke(dst+0x1000,data);
        dst-=0x2000;
        src1++;dst++;
    }
}

void writeTileCombos() {
    int i,j,d,s;
    int pat;
    unsigned int shf,lhs,rhs,col;
    unsigned char *src1, *src2,*dst;

    for(j=0;j<16;j++) {
        for(i=0;i<16;i++) {
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

void calcTileHit(unsigned char tile, unsigned char idx) {
    unsigned char hit;

    hit=0;

    if((tile>=1)&&(tile<=5)) hit=1;         // Piece of land
    if((tile>=6)&&(tile<=7)) hit=2;         // Fuel
    if((tile>=8)&&(tile<=9)) hit=3;         // Bonus
    if((tile>=10)&&(tile<=11)) hit=4;       // Life pod

    tileHit[idx]=hit;
}

// Index to tiles and what the hit means
// lhs takes precendce most of the time
void processTileHit(unsigned char lhs, unsigned char rhs) {
    unsigned char idx;

    idx=nameIdx;
    calcTileHit(lhs, idx++);
    calcTileHit(lhs, idx++);
    calcTileHit(rhs, idx++);
    calcTileHit(rhs, idx++);
}

// Each tile needs a scrolled version with each version an adjacent tile including self
// Scrolling is 2 pixels so need 4 versions of each tile including un-scrolled
// Total tiles needed t = PROJECT_TILE_COUNT*PROJECT_TILE_COUNT*4
// For 8 combos, thats 8*8*4=256

void processTileCombo(unsigned char t1, unsigned char t2) {
    if(tileCombos[t2][t1]==0) {
        tileCombos[t2][t1]=nameIdx;
        processTileHit(t1, t2);
        maxCombos++;
        nameIdx += 4;
    }
}

void initSuperTileDef() {
    int i,j,superIdx1,superIdx2;
    unsigned char tile1, tile2;

    for(i=0;i<256;i++) {
        tileHit[i]=0;
    }
    for(j=0; j<16; j++) {
        for(i=0; i<16; i++) {
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

void process_starfield() {
    int x,y;

    maxstars=0;
    for(y=0;y<(PROJECT_MAP_HEIGHT*2);y++) {
        for(x=0;x<32;x++) {
            if(starfield[y][x]) {
                staridxl[maxstars]=(y*32)%256;
                staridxh[maxstars]=(y*32)/256;
                staryoff[maxstars]=x;
                starpat[maxstars]=starfield[y][x]*4;
                maxstars++;
            }
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
    printf("  Star idx = %d  \r", maxstars);

    k=0;
    for(j=0;j<8;j++) {
        for(i=0;i<32;i++) {
            dfcl_plot(i,j+16,k++);
        }
    }
}


void init_sprites() {
    int i;

    for(i=0; i<FOES;i++) {
        foe_col1[i]=i%14+2;
        foe_col2[i]=(i+3)%14+2;
        foe_pat1[i]=16+(i%4);
        foe_pat2[i]=20+(i%4);
        foe_data1[i]=40+i*4;
        foe_data2[i]=(i*5)%128;
        foe_counter[i]=8;
        foe_y[i]=foe_data1[i];
        foe_xl[i]=((i*29)%1024)%256;
        foe_xh[i]=((i*29)%1024)/256;
        if(i&1) {
            foe_vecl[i]=((unsigned int)&foe_simple)%256;
            foe_vech[i]=((unsigned int)&foe_simple)/256;
        } else {
            foe_vecl[i]=((unsigned int)&foe_static)%256;
            foe_vech[i]=((unsigned int)&foe_static)/256;
        }
    }

    // Player pattern
    // 0,1=right colour 1
    // 2,3=right colour 2
    spr_pat[0]=0;
    spr_pat[1]=1;
    spr_pat[2]=2;
    spr_pat[3]=3;
    // 0,1 = colour 1 white
    // 2,3 = colour 2 blue
    spr_col[0]=14;
    spr_col[1]=14;
    spr_col[2]=4;
    spr_col[3]=4;

    for(i=0; i<(24*8); i++) {
        dfcl_vpoke((unsigned char*)(0x1800+i),spritePattern[i]);
    }
}


int main() {
    char k;
    unsigned char z, del;

    dfcl_mode(0x2);
    dfcl_cursor(1);
    dfcl_colour(32,1,1);

    int_delay=0;
    int_c=0;

    dfcl_vbint(vb_handler);

    k=0;

   
    z=0;
    initScrBuf(0);
    initSuperTileDef();
    writeTileCombos();
    writeNormalTiles();
    process_starfield();
    init_sprites();

    showStats();
    dfcl_wait(100);
    spr_cycle=0;
    scroll=0;
    del=0;
    sprite_space=16;
    int_invoked=0;
    int_render=0;
    p_x=128;
    p_y=10;
    p_dx=0;
    p_ddx=0;
    p_vx=0;
    p_fx=8;
    p_spr=0;
    do {
        move_player();
        mapX=scroll>>2;
        mapS=scroll&3;
        move_laser();
        move_foes();
        while(int_delay) {}
        spr_to_buf();
        renderViewAsm();
        int_delay=VBDELAY;

//        dfcl_gotoxy(0,22);
//        printf("%5d %5d %5d %5d    ",p_ddx,p_dx,p_vx,p_ex);
    }while(1);

    return 0xd010;
} 
