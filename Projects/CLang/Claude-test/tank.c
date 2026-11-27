/*
 * tank.c - first-person 3D wireframe tank game for the DOLO-128
 *
 * Drive around a wrapping battlefield with obstacles and a scrolling
 * mountain skyline, hunt the enemy tank with radar and shoot it.
 *
 * Build options (cc65 -D...):
 *   AUTOPILOT  hunt and shoot the enemy by itself (testing without a joystick)
 *   SHOTTEST   sit still and fire continuously (add -DSHSPEED=3 for slow shells)
 *   NORESTART  with AUTOPILOT: stay on the game over screen
 *   BENCH      time each rendering stage and show the results
 *   TESTPAT    draw a line drawing test pattern
 */
#include <stdlib.h>
#include <cc65.h>
#include "../HB128/hb128.h"

/* ---- assembly interfaces ---- */
/* gfx.s */
extern unsigned char lx0, ly0, lx1, ly1, gfx_base;
#pragma zpsym("gfx_base")
#pragma zpsym("lx0")
#pragma zpsym("ly0")
#pragma zpsym("lx1")
#pragma zpsym("ly1")
extern void gfx_init(void);
extern void gfx_line(void);
extern void gfx_blit(void);
extern void __fastcall__ gfx_mark(unsigned int off);
extern void __fastcall__ gfx_vput8(unsigned int vaddr);
extern const unsigned char *gfx_src;
extern unsigned char fb[], bg[];
/* math.s */
extern int __fastcall__ smul(int a, signed char s);   /* a*s/128  */
extern int __fastcall__ pdiv(int a, int z);           /* a*256/z  */
/* xform.s */
extern unsigned int tc_x, tc_z;
extern unsigned char to_camera(void);   /* (tc_x,tc_z) -> ccx, ccz */
extern void xform_model(void);
extern void draw_edges(void);
extern const void *xf_model;
extern int xf_ccx, xf_ccz;
extern signed char xf_sa, xf_ca;
/* input.s - joystick read in the vblank interrupt */
extern void input_init(void);
extern volatile unsigned char joy_now;     /* current J_* bits */
extern volatile unsigned char joy_fire;    /* set on each fire press */
/* sound.s - effects played by the vblank interrupt; set a flag to trigger */
extern volatile unsigned char sfx_pshot, sfx_eshot, sfx_eboom, sfx_pboom, sfx_ping;
extern volatile unsigned char engine;      /* 0 off, 1 idle, 2 moving */
/* tables.s, font.s */
extern const signed char sintab[256];
extern const unsigned char hudfont[];

#define SIN(a) sintab[(unsigned char)(a)]
#define COS(a) sintab[(unsigned char)((a) + 64)]

/* Sine of a full 16 bit angle (65536 = full circle), interpolated between
 * table entries. The player's heading uses this so aiming isn't limited to
 * the table's 256 directions. */
static signed char fsin(unsigned int a)
{
    unsigned char i = a >> 8;
    signed char s0 = sintab[i];
    return s0 + (signed char)(((int)(sintab[(unsigned char)(i + 1)] - s0) * (unsigned char)a + 128) >> 8);
}
#define FSIN(a) fsin(a)
#define FCOS(a) fsin((a) + 0x4000)

#define TICKS (*(volatile unsigned char *)0x0004)   /* VDP frame counter */

#define J_FIRE  0x80
#define J_LEFT  0x40
#define J_RIGHT 0x20
#define J_UP    0x10
#define J_DOWN  0x08

/* ---- screen layout ---- */
#define HUD_ROWS 4                  /* top 4 character rows = HUD (red) */
#define VTOP     (HUD_ROWS * 8)     /* first line of the 3D view */
#define VBOT     191
#define HORIZON  104                /* must match xform.s */
#define CENTREX  128

/* ---- world ---- */
#define CAMH     24                 /* camera height (must match xform.s) */
#define NEARZ    16                 /* near plane (must match xform.s) */
#define FARZ     3000
#define WSIZE    8192               /* world wraps every 8192 units */
#define WMASK    (WSIZE - 1)
#define WHALF    (WSIZE / 2)

/* ======================================================================= */
/* Models                                                                   */
/* ======================================================================= */
typedef struct { signed char x, y, z; } Vtx;
typedef struct {                    /* layout is relied on by xform.s */
    unsigned char nv, ne;
    const Vtx *v;
    const unsigned char *e;         /* pairs of vertex indices */
    unsigned char radius;           /* for culling and collisions */
} Model;

static const Vtx cube_v[] = {
    {-30, 0,-30}, { 30, 0,-30}, { 30, 0, 30}, {-30, 0, 30},
    {-30,60,-30}, { 30,60,-30}, { 30,60, 30}, {-30,60, 30}
};
static const unsigned char box_e[] = {
    0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4, 0,4, 1,5, 2,6, 3,7
};
static const Vtx pyr_v[] = {
    {-40, 0,-40}, { 40, 0,-40}, { 40, 0, 40}, {-40, 0, 40}, {0, 90, 0}
};
static const unsigned char pyr_e[] = {
    0,1, 1,2, 2,3, 3,0, 0,4, 1,4, 2,4, 3,4
};
static const Vtx tower_v[] = {
    {-16, 0,-16}, { 16, 0,-16}, { 16, 0, 16}, {-16, 0, 16},
    {-16,110,-16},{ 16,110,-16},{ 16,110, 16},{-16,110, 16}
};

/* Enemy tank: three-tier hull, turret and gun. Front is +z. */
static const Vtx tank_v[] = {
    {-34, 0,-50}, { 34, 0,-50}, { 34, 0, 50}, {-34, 0, 50},     /* 0 tracks bottom */
    {-40,12,-60}, { 40,12,-60}, { 40,12, 66}, {-40,12, 66},     /* 4 track tops   */
    {-32,22,-50}, { 32,22,-50}, { 32,22, 40}, {-32,22, 40},     /* 8 deck         */
    {-20,22,-36}, { 20,22,-36}, { 20,22, 10}, {-20,22, 10},     /* 12 turret base */
    {-14,38,-30}, { 14,38,-30}, { 14,38,  4}, {-14,38,  4},     /* 16 turret top  */
    {  0,30,  8}, {  0,30, 84}                                  /* 20 gun         */
};
static const unsigned char tank_e[] = {
    0,1, 1,2, 2,3, 3,0,
    4,5, 5,6, 6,7, 7,4,
    8,9, 9,10, 10,11, 11,8,
    0,4, 1,5, 2,6, 3,7,
    4,8, 5,9, 6,10, 7,11,
    16,17, 17,18, 18,19, 19,16,
    12,16, 13,17, 14,18, 15,19,
    20,21
};

enum { M_CUBE, M_PYRAMID, M_TOWER, M_TANK };
static const Model models[] = {
    { 8, 12, cube_v,  box_e,  30 },
    { 5,  8, pyr_v,   pyr_e,  40 },
    { 8, 12, tower_v, box_e,  16 },
    {22, 29, tank_v,  tank_e, 66 }
};

/* ======================================================================= */
/* World state                                                              */
/* ======================================================================= */
#define NOBST 24
typedef struct { unsigned int x, z; unsigned char ang, model; } Obj;
static Obj obst[NOBST];

unsigned int px, pz;                /* player position (used by xform.s) */
static unsigned int ph;             /* player heading, 8.8 (hi byte = 0..255) */
signed char ps, pc;                 /* sin/cos of heading this frame (xform.s) */

static unsigned int ex, ez;         /* enemy tank */
static unsigned char eang;
static int ecx, ecz;                /* enemy in camera space (for radar) */
static unsigned char evis;
static unsigned char edead;         /* 0 = alive, else ticks since destroyed */
static unsigned char pdead;         /* 0 = alive, else ticks since hit */
static unsigned char lives;
static unsigned char gameover;

static unsigned char dt;            /* ticks since last frame (capped) */
static unsigned int frames;
static unsigned int score;

/* Signed distance a-b on the wrapping world */
static int wrapd(unsigned int a, unsigned int b)
{
    int d = (int)((a - b) & WMASK);
    if (d >= WHALF) d -= WSIZE;
    return d;
}

/* a*b/c with a 32 bit intermediate (cc65's fast asm helpers) */
#define MULDIV(a, b, c) ((int)idiv32by16r16(imul16x16r32((a), (b)), (c)))

/* ======================================================================= */
/* 2D line clipping (Cohen-Sutherland) to the 3D view window                */
/* ======================================================================= */
static int cx0, cy0, cx1, cy1;
unsigned char clipy = VTOP;         /* top of the clip window (used by xform.s) */

#define OC_L 1
#define OC_R 2
#define OC_T 4
#define OC_B 8

static unsigned char outcode(int x, int y)
{
    unsigned char c = 0;
    if (x < 0) c = OC_L; else if (x > 255) c = OC_R;
    if (y < (int)clipy) c |= OC_T; else if (y > VBOT) c |= OC_B;
    return c;
}

static void drawline(void)
{
    unsigned char c0, c1, c;
    int x, y;

    /* fast accept: everything already on screen */
    if (!((cx0 | cx1 | cy0 | cy1) & 0xff00) &&
        (unsigned char)cy0 >= clipy && (unsigned char)cy0 <= VBOT &&
        (unsigned char)cy1 >= clipy && (unsigned char)cy1 <= VBOT) {
        lx0 = cx0; ly0 = cy0; lx1 = cx1; ly1 = cy1;
        gfx_line();
        return;
    }

    c0 = outcode(cx0, cy0);
    c1 = outcode(cx1, cy1);
    while (c0 | c1) {
        if (c0 & c1) return;
        c = c0 ? c0 : c1;
        if (c & OC_T) {
            y = clipy;
            x = cx0 + MULDIV(cx1 - cx0, y - cy0, cy1 - cy0);
        } else if (c & OC_B) {
            y = VBOT;
            x = cx0 + MULDIV(cx1 - cx0, y - cy0, cy1 - cy0);
        } else if (c & OC_L) {
            x = 0;
            y = cy0 + MULDIV(cy1 - cy0, x - cx0, cx1 - cx0);
        } else {
            x = 255;
            y = cy0 + MULDIV(cy1 - cy0, x - cx0, cx1 - cx0);
        }
        if (c == c0) { cx0 = x; cy0 = y; c0 = outcode(x, y); }
        else         { cx1 = x; cy1 = y; c1 = outcode(x, y); }
    }
    lx0 = cx0; ly0 = cy0; lx1 = cx1; ly1 = cy1;
    gfx_line();
}

/* Unclipped line, for HUD graphics that are always on screen */
static void hline(unsigned char x0, unsigned char y0, unsigned char x1, unsigned char y1)
{
    lx0 = x0; ly0 = y0; lx1 = x1; ly1 = y1;
    gfx_line();
}

/* ======================================================================= */
/* 3D object rendering                                                      */
/* ======================================================================= */
#define MAXV 24
/* filled in by xform_model (xform.s) */
int vx[MAXV], vy[MAXV], vz[MAXV];   /* camera space */
int sx[MAXV], sy[MAXV];             /* screen space */
unsigned char vfront[MAXV];         /* z >= NEARZ */

/* Called by draw_edges (xform.s) for edges that need clipping */
void __fastcall__ edge_slow(unsigned char a, unsigned char b)
{
    unsigned char t;
    int num, den, x, y;

    if (vfront[a] && vfront[b]) {
        cx0 = sx[a]; cy0 = sy[a]; cx1 = sx[b]; cy1 = sy[b];
        drawline();
        return;
    }
    if (!vfront[a]) { t = a; a = b; b = t; }    /* a in front, b behind */
    num = NEARZ - vz[a];
    den = vz[b] - vz[a];
    x = vx[a] + MULDIV(vx[b] - vx[a], num, den);
    y = vy[a] + MULDIV(vy[b] - vy[a], num, den);
    cx0 = sx[a]; cy0 = sy[a];
    cx1 = CENTREX + pdiv(x, NEARZ);
    cy1 = HORIZON - pdiv(y, NEARZ);
    drawline();
}

/* Object centre in camera space, set by to_camera() in xform.s */
int ccx, ccz;

static void draw_model(unsigned char ang, const Model *m)
{
    unsigned char a;
    int r = m->radius;

    /* cull: behind, too far, or outside the ~53 degree view cone */
    if (ccz < -r || ccz > FARZ) return;
    if (ccx > (ccz >> 1) + r + (r >> 1)) return;
    if (-ccx > (ccz >> 1) + r + (r >> 1)) return;

    a = ang - (unsigned char)((ph + 0x80) >> 8);  /* nearest step */
    xf_sa = SIN(a);
    xf_ca = COS(a);
    xf_ccx = ccx;
    xf_ccz = ccz;
    xf_model = m;
    xform_model();
    draw_edges();
}

/* ======================================================================= */
/* Skyline                                                                  */
/* ======================================================================= */
#define NMTN 64
static const unsigned char mtn_h[NMTN] = {
     6,11,15, 8, 9,19,27,34, 39,30,21,17,12, 7, 4, 6,
     9,12,14,22,24,20,18,10,  8, 5, 3, 7,12,25,33,38,
    42,35,30,24,17,12, 9,13, 18,23,26,19,14, 9, 6, 4,
     3, 6,10,16,20,29,36,28, 23,15,11, 8, 7, 5, 4, 5
};

static void draw_mountains(void)
{
    unsigned char i, k;
    int rel, x, prevx = 0;

    /* mountain points every 1024 heading units (1/64 of a circle); only
     * the 14 points around the current heading can be on screen */
    i = (unsigned char)(ph >> 10) - 6;
    for (k = 0; k < 14; ++k, ++i) {
        i &= NMTN - 1;
        rel = (int)(((unsigned int)i << 10) - ph);
        /* 256*tan(angle) ~= rel/41 at the screen scale used by pdiv */
        x = CENTREX + smul(rel >> 4, 50);
        if (k) {
            cx0 = prevx; cy0 = HORIZON - mtn_h[(i - 1) & (NMTN - 1)];
            cx1 = x;     cy1 = HORIZON - mtn_h[i];
            drawline();
        }
        prevx = x;
    }
}

/* ======================================================================= */
/* HUD                                                                      */
/* ======================================================================= */

/* HUD text is written straight to VRAM, and only when it changes. Those
 * cells are never drawn in the framebuffer, so gfx_blit leaves them alone. */
static void vtext(unsigned char col, unsigned char row, const char *s)
{
    unsigned char ch;
    unsigned int va = ((unsigned int)row << 8) + (col << 3);
    while ((ch = *s++) != 0) {
        if (ch >= 'a' && ch <= 'z') ch -= 32;
        if (ch < 32 || ch >= 96) ch = 32;
        gfx_src = hudfont + ((ch - 32) << 3);
        gfx_vput8(va);
        va += 8;
    }
}

static char numbuf[6];
static char *num(unsigned int n, unsigned char width)
{
    char *p = numbuf + 5;
    *p = 0;
    do {
        *--p = '0' + (n % 10);
        n /= 10;
        --width;
    } while (n || (width && p > numbuf));
    return p;
}

#define RADX 128
#define RADY 16
#define RADR 14
static unsigned char sweep;
static unsigned char radx[17], rady[17];

static void init_radar(void)
{
    unsigned char i;
    for (i = 0; i <= 16; ++i) {
        radx[i] = RADX + smul(RADR, SIN(i << 4));
        rady[i] = RADY - smul(RADR, COS(i << 4));
    }
}

static void draw_bg_radar(void)
{
    unsigned char i;
    for (i = 0; i < 16; ++i)
        hline(radx[i], rady[i], radx[i + 1], rady[i + 1]);
    /* field of view marks */
    hline(RADX, RADY, RADX - 5, RADY - 10);
    hline(RADX, RADY, RADX + 5, RADY - 10);
}

static unsigned char blip_was_shown;

static void draw_radar(void)
{
    unsigned char shown;
    int bx, by;
    unsigned char x0, y0;

    /* sweep */
    sweep += dt << 2;
    hline(RADX, RADY, RADX + smul(RADR - 1, SIN(sweep)), RADY - smul(RADR - 1, COS(sweep)));

    /* enemy blip: 1 radar pixel = 256 units, so the radar reaches about
     * 3000 units - further than new enemies spawn. Ping when it shows up. */
    shown = 0;
    if (evis) {
        bx = ecx >> 8;
        by = ecz >> 8;
        if (bx * bx + by * by < (RADR - 2) * (RADR - 2)) {
            x0 = RADX + bx;
            y0 = RADY - by;
            hline(x0 - 1, y0, x0 + 1, y0);
            hline(x0, y0 - 1, x0, y0 + 1);
            shown = 1;
        }
    }
    if (shown && !blip_was_shown) sfx_ping = 1;
    blip_was_shown = shown;
}

static void draw_bg_sight(void)
{
    /* two brackets above and below the aim point on the horizon */
    hline(CENTREX - 8, HORIZON - 14, CENTREX + 8, HORIZON - 14);
    hline(CENTREX - 8, HORIZON - 14, CENTREX - 8, HORIZON - 9);
    hline(CENTREX + 8, HORIZON - 14, CENTREX + 8, HORIZON - 9);
    hline(CENTREX, HORIZON - 14, CENTREX, HORIZON - 5);
    hline(CENTREX - 8, HORIZON + 14, CENTREX + 8, HORIZON + 14);
    hline(CENTREX - 8, HORIZON + 14, CENTREX - 8, HORIZON + 9);
    hline(CENTREX + 8, HORIZON + 14, CENTREX + 8, HORIZON + 9);
    hline(CENTREX, HORIZON + 14, CENTREX, HORIZON + 5);
}

/* last values shown, so the HUD is only redrawn when something changes */
static unsigned int hud_score = 0xffff;
static unsigned char hud_msg = 0xff, hud_lives = 0xff;

static void update_hud(void)
{
    unsigned char msg;
    if (hud_msg == 0xff) {              /* first time: static labels */
        vtext(23, 0, "SCORE");
    }
    if (score != hud_score) {
        hud_score = score;
        vtext(23, 1, num(score, 5));
    }
    if (lives != hud_lives) {
        hud_lives = lives;
        vtext(23, 3, "LIVES ");
        vtext(29, 3, num(lives, 1));
    }
    msg = 0;
    if (gameover) msg = 5;
    else if (pdead) msg = 4;
    else if (edead) msg = 3;
    else if (evis) {
        msg = 1;
        if (ecz > 0 && ecx < (ecz >> 1) && -ecx < (ecz >> 1)) msg = 2;
    }
    if (msg != hud_msg) {
        hud_msg = msg;
        vtext(0, 3, msg == 5 ? "GAME OVER     " : msg == 4 ? "YOU WERE HIT  " :
                    msg == 3 ? "TANK DESTROYED" : msg == 2 ? "ENEMY IN VIEW " :
                    msg == 1 ? "ENEMY ON RADAR" : "              ");
    }
}

/* ======================================================================= */
/* Collisions                                                               */
/* ======================================================================= */
static unsigned char blocked(unsigned int x, unsigned int z, int r)
{
    unsigned char i;
    int d, lim;
    for (i = 0; i < NOBST; ++i) {
        lim = models[obst[i].model].radius + r;
        d = wrapd(obst[i].x, x);
        if (d < lim && d > -lim) {
            d = wrapd(obst[i].z, z);
            if (d < lim && d > -lim) return 1;
        }
    }
    return 0;
}

/* ======================================================================= */
/* Shooting                                                                 */
/* ======================================================================= */
static unsigned int rnd(void);

/* Shell: a small double-pointed shape, nose towards +z */
static const Vtx shell_v[] = {
    {0,18,9}, {0,18,-9}, {-4,18,0}, {4,18,0}, {0,22,0}, {0,14,0}
};
static const unsigned char shell_e[] = {
    0,2, 0,3, 0,4, 0,5, 1,2, 1,3, 1,4, 1,5, 2,4, 4,3, 3,5, 5,2
};
static const Model shell_model = { 6, 12, shell_v, shell_e, 10 };

/* speeds are units per tick and must be even (shells move in half steps) */
#ifndef SHSPEED
#define SHSPEED  40     /* player's shell */
#endif
#define ESHSPEED 22     /* enemy's shell: slower, so it can be dodged */
#define SHRANGE  2400   /* units before a shell burns out */
#define SHRAD    6      /* shell collision size */
#define ERAD     50     /* enemy tank hit box (half size) */
#define PHIT     40     /* player hit box (half size) */
#define EBOOM    60     /* ticks the enemy explosion lasts */
#define PDEAD    150    /* ticks before carrying on after being hit */
#define LIVES    3
#define ERANGE   2000   /* enemy only fires when closer than this */

typedef struct {
    unsigned char on, ang, step;    /* step = units moved per half tick */
    unsigned int x, z;
    int vx, vz;                     /* velocity, 1/16 units per half tick */
    int fx, fz;                     /* fractional position, 1/16 units */
    int dist;
} Shell;
static Shell pshell, eshell;        /* player's and enemy's shell */

static unsigned char lastfire;
static unsigned int boomx, boomz;   /* where the enemy blew up */
static unsigned char boomang;
static unsigned char flash;         /* ticks of coloured border left */
static unsigned char ecool;         /* ticks before the enemy can fire again */

static void border(unsigned char ticks, unsigned char colour)
{
    flash = ticks;
    dfcl_vdp_setreg(7, 0xf0 | colour);
}

/* ang orients the shell model; s/c are the sine/cosine of its direction */
static void launch(Shell *sh, unsigned int x, unsigned int z, unsigned char ang,
                   signed char s, signed char c, unsigned char speed)
{
    sh->on = 1;
    sh->ang = ang;
    sh->step = speed >> 1;
    sh->vx = smul(speed * 8, s);
    sh->vz = smul(speed * 8, c);
    sh->x = (x + smul(40, s)) & WMASK;          /* start at the gun muzzle */
    sh->z = (z + smul(40, c)) & WMASK;
    sh->fx = sh->fz = 0;
    sh->dist = 0;
}

/* Move a shell half a tick. Returns 0 if it burnt out or hit an obstacle. */
static unsigned char shell_step(Shell *sh)
{
    sh->fx += sh->vx;
    sh->fz += sh->vz;
    sh->x = (sh->x + (sh->fx >> 4)) & WMASK;
    sh->z = (sh->z + (sh->fz >> 4)) & WMASK;
    sh->fx &= 15;
    sh->fz &= 15;
    sh->dist += sh->step;
    if (sh->dist > SHRANGE || blocked(sh->x, sh->z, SHRAD)) {
        sh->on = 0;
        return 0;
    }
    return 1;
}

/* Are two points within r of each other (square box) on the wrapping world? */
static unsigned char close_to(unsigned int x0, unsigned int z0,
                              unsigned int x1, unsigned int z1, int r)
{
    int d = wrapd(x0, x1);
    if (d >= r || d <= -r) return 0;
    d = wrapd(z0, z1);
    return d < r && d > -r;
}

static void kill_enemy(void)
{
    edead = 1;
    boomx = ex;
    boomz = ez;
    boomang = rnd() >> 8;
    score += 1000;
    border(6, 8);                           /* red flash */
    sfx_eboom = 1;
}

static void hit_player(void)
{
    pdead = 1;
    if (lives) --lives;
    pshell.on = 0;
    eshell.on = 0;
    border(30, 8);
    sfx_pboom = 1;
}

static void move_shells(void)
{
    unsigned char n;
    /* half a tick at a time so shells can't jump through thin obstacles */
    for (n = dt << 1; n; --n) {
        if (pshell.on && shell_step(&pshell) && !edead &&
            close_to(pshell.x, pshell.z, ex, ez, ERAD)) {
            pshell.on = 0;
            kill_enemy();
        }
        if (eshell.on && shell_step(&eshell) && !pdead &&
            close_to(eshell.x, eshell.z, px, pz, PHIT)) {
            eshell.on = 0;
            hit_player();
        }
    }
}

/* Explosion: six tumbling triangles flung outwards and falling back */
#define NDEB 6
static Vtx debris_v[NDEB * 3];
static const unsigned char debris_e[] = {
     0, 1,  1, 2,  2, 0,   3, 4,  4, 5,  5, 3,   6, 7,  7, 8,  8, 6,
     9,10, 10,11, 11, 9,  12,13, 13,14, 14,12,  15,16, 16,17, 17,15
};
static const Model debris_model = { NDEB * 3, NDEB * 3, debris_v, debris_e, 120 };

static void build_debris(void)
{
    unsigned char i, a, t = edead;
    int r, y;
    signed char cx, cz, ox, oy;
    Vtx *v = debris_v;

    r = t * 3;
    if (r > 110) r = 110;
    for (i = 0; i < NDEB; ++i, v += 3) {
        a = boomang + i * 43;
        cx = smul(r, SIN(a));
        cz = smul(r, COS(a));
        y = 10 + ((i & 1) ? 5 : 3) * t - ((t * t) >> 4);
        if (y < 8) y = 8;
        if (y > 110) y = 110;
        a = t * 12 + i * 40;                    /* tumble */
        ox = smul(8, SIN(a));
        oy = smul(8, COS(a));
        v[0].x = cx + ox; v[0].y = y + oy; v[0].z = cz;
        v[1].x = cx - ox; v[1].y = y - oy; v[1].z = cz;
        v[2].x = cx;      v[2].y = y;      v[2].z = cz + 9;
    }
}

static void spawn_enemy(void)
{
    unsigned char a;
    int dist;
    do {
        a = rnd() >> 8;
        dist = 1800 + (rnd() & 511) + (rnd() & 255);
        ex = (px + smul(dist, SIN(a))) & WMASK;
        ez = (pz + smul(dist, COS(a))) & WMASK;
    } while (blocked(ex, ez, 80));
    eang = rnd() >> 8;
    edead = 0;
    ecool = 120;                            /* a moment's grace */
}

static void new_game(void)
{
    score = 0;
    lives = LIVES;
    pdead = 0;
    gameover = 0;
    pshell.on = 0;
    eshell.on = 0;
    spawn_enemy();
}

/* ======================================================================= */
/* Movement                                                                 */
/* ======================================================================= */
#define PSPEED 5        /* units per tick */
#define PTURN_MIN 0x20  /* turn speed when you start turning (fine aim), */
#define PTURN_MAX 0xA0  /* ...building up to this while held. Heading units */
#define PTURN_ACC 6     /* (65536 = full circle) per tick; ACC per tick held */
#define PRAD   36

static unsigned char read_input(void)
{
#ifdef SHOTTEST
    /* test build: sit still and keep firing (one shell in flight at a time) */
    return (frames & 1) ? J_FIRE : 0;
#endif
#ifdef AUTOPILOT
    /* test build: hunt the enemy - turn towards it and fire when lined up,
     * otherwise drive around */
#ifdef NORESTART
    if (gameover) return 0;             /* stay on the game over screen */
#endif
    if (gameover) return (frames & 1) ? J_FIRE : 0;
    if (evis && !edead && ecz > 0) {
        if (ecx > (ecz >> 5) + 6)       return J_RIGHT;
        if (ecx < -(ecz >> 5) - 6)      return J_LEFT;
        return (frames & 1) ? J_FIRE : 0;
    }
    return J_RIGHT | (((frames >> 5) & 1) ? J_UP : 0);
#else
    return joy_now;
#endif
}

static unsigned char turnrate = PTURN_MIN, lastturn;

static void move_player(void)
{
    unsigned char j = read_input();
    unsigned char pressed;
    int step = 0;
    unsigned int nx, nz;
    unsigned char turn;

    /* a new fire press: either seen by the vblank interrupt (catches taps
     * shorter than a game frame) or as a change since the last frame */
    pressed = joy_fire || ((j & J_FIRE) && !(lastfire & J_FIRE));
    joy_fire = 0;
    lastfire = j;

    if (pdead) {
        engine = 0;
        if (pdead < 250) pdead += dt;
        if (gameover) {
            if (pressed && pdead > 60) new_game();
        } else if (pdead > PDEAD) {
            if (lives) {
                pdead = 0;
                spawn_enemy();              /* carry on with a fresh enemy */
            } else {
                gameover = 1;
                pdead = 1;
            }
        }
        return;
    }

    if (pressed && !pshell.on) {
        launch(&pshell, px, pz, ph >> 8, FSIN(ph), FCOS(ph), SHSPEED);
        sfx_pshot = 1;
    }
    engine = (j & (J_LEFT | J_RIGHT | J_UP | J_DOWN)) ? 2 : 1;

    /* turning starts slowly so a tap makes a small adjustment, then speeds
     * up the longer the direction is held */
    turn = j & (J_LEFT | J_RIGHT);
    if (turn && turn == lastturn) {
        turnrate += PTURN_ACC * dt;
        if (turnrate > PTURN_MAX) turnrate = PTURN_MAX;
    } else {
        turnrate = PTURN_MIN;
    }
    lastturn = turn;
    if (turn == J_LEFT)  ph -= turnrate * dt;
    if (turn == J_RIGHT) ph += turnrate * dt;

    if (j & J_UP)    step = PSPEED * dt;
    if (j & J_DOWN)  step = -(PSPEED * dt) / 2;
    if (step) {
        nx = px + smul(step, FSIN(ph));
        nz = pz + smul(step, FCOS(ph));
        if (blocked(nx, nz, PRAD)) return;
        if (!edead && close_to(nx, nz, ex, ez, 90)) return;   /* bumped the enemy */
        px = nx & WMASK;
        pz = nz & WMASK;
    }
}

static void move_enemy(void)
{
    int dx, dz, rx, rz, aim;
    signed char s, c;
    unsigned int nx, nz;

    if (flash) {
        if (flash <= dt) {
            flash = 0;
            dfcl_vdp_setreg(7, 0xf1);           /* border back to black */
        } else {
            flash -= dt;
        }
    }
    if (edead) {
        edead += dt;
        if (edead > EBOOM) spawn_enemy();
        return;
    }
    if (pdead) return;                          /* hold still while we recover */

    dx = wrapd(px, ex);
    dz = wrapd(pz, ez);
    s = SIN(eang);
    c = COS(eang);
    rx = smul(dx, c) - smul(dz, s);         /* player relative to enemy */
    rz = smul(dx, s) + smul(dz, c);

    if (rz < 0 || rx > 12)      eang += dt;
    else if (rx < -12)          eang -= dt;

    /* fire when lined up and in range */
    if (ecool > dt) ecool -= dt; else ecool = 0;
    aim = 20 + (rz >> 5);
    if (!ecool && !eshell.on && rz > 0 && rz < ERANGE && rx < aim && -rx < aim) {
        launch(&eshell, ex, ez, eang, SIN(eang), COS(eang), ESHSPEED);
        sfx_eshot = 1;
        ecool = 90 + (rnd() & 63);
    }

    /* close in until about 500 units away, while roughly facing the player */
    if (rz > 500 && (rx < (rz >> 2) && -rx < (rz >> 2))) {
        nx = ex + smul(3 * dt, SIN(eang));
        nz = ez + smul(3 * dt, COS(eang));
        if (!blocked(nx, nz, 66)) {
            ex = nx & WMASK;
            ez = nz & WMASK;
        } else {
            eang += 8;      /* steer round obstacles */
        }
    }
}

/* ======================================================================= */
/* Setup                                                                    */
/* ======================================================================= */
static unsigned int seed = 12345;
static unsigned int rnd(void)
{
    seed = seed * 25173u + 13849u;
    return seed;
}

static void init_world(void)
{
    unsigned char i;
    for (i = 0; i < NOBST; ++i) {
        do {
            obst[i].x = rnd() & WMASK;
            obst[i].z = rnd() & WMASK;
        } while (wrapd(obst[i].x, 0) < 300 && wrapd(obst[i].x, 0) > -300 &&
                 wrapd(obst[i].z, 0) < 300 && wrapd(obst[i].z, 0) > -300);
        obst[i].ang = rnd() >> 8;
        obst[i].model = (rnd() >> 8) % 3;
    }
    /* a few landmarks near the start so there's something to look at */
    obst[0].x = 0;    obst[0].z = 500;  obst[0].model = M_CUBE;    obst[0].ang = 20;
    obst[1].x = 300;  obst[1].z = 800;  obst[1].model = M_PYRAMID; obst[1].ang = 0;
    obst[2].x = WSIZE - 350; obst[2].z = 650; obst[2].model = M_TOWER; obst[2].ang = 0;

    px = 0; pz = 0; ph = 0;
    ex = 150; ez = 1400; eang = 150;
    lives = LIVES;
    ecool = 180;
}

static void init_screen(void)
{
    unsigned int a;
    dfcl_mode(0x31);                    /* hires, light green on black */
    /* HUD rows in red */
    for (a = 0x2000; a < 0x2000 + HUD_ROWS * 256; ++a)
        dfcl_vpoke((unsigned char *)a, 0x81);
    gfx_init();
    init_radar();

    /* static graphics go in the background buffer, drawn once */
    gfx_base = (unsigned int)bg >> 8;
    hline(0, HORIZON, 255, HORIZON);
    draw_bg_sight();
    draw_bg_radar();
    gfx_base = (unsigned int)fb >> 8;
}

/* Cracked windscreen when hit: jagged lines out from the impact point */
static const unsigned char cracks[] = {
    150,130, 118,112,  118,112,  96,118,   96,118,  60, 96,   60, 96,  20, 90,
     20, 90,   0, 70,  150,130, 176,104,  176,104, 190, 80,  190, 80, 226, 58,
    226, 58, 255, 48,  150,130, 132,156,  132,156, 140,176,  140,176, 120,191,
    150,130, 184,140,  184,140, 214,136,  214,136, 255,158,  150,130, 160,170,
    160,170, 184,191,  118,112, 124, 88,  124, 88, 110, 60,  110, 60, 118, 34,
    184,140, 196,166,  196,166, 232,184,   60, 96,  52,128,   52,128,  14,150,
    142,124, 156,122,  156,122, 160,134,  160,134, 146,138,  146,138, 142,124
};

static void draw_cracks(void)
{
    const unsigned char *p = cracks;
    unsigned char n;
    for (n = sizeof(cracks) / 4; n; --n, p += 4)
        hline(p[0], p[1], p[2], p[3]);
}

/* Text drawn into the framebuffer (for messages over the 3D view) */
static void fbtext(unsigned char col, unsigned char row, const char *str)
{
    unsigned char ch, i;
    unsigned int off;
    unsigned char *p;
    const unsigned char *g;
    while ((ch = *str++) != 0) {
        if (ch > ' ' && ch < 96) {
            off = ((unsigned int)row << 8) + (col << 3);
            p = fb + off;
            g = hudfont + ((ch - 32) << 3);
            for (i = 0; i < 8; ++i) p[i] |= g[i];
            gfx_mark(off);
        }
        ++col;
    }
}

static void render(void)
{
    unsigned char i;

    ps = FSIN(ph);
    pc = FCOS(ph);

    draw_mountains();

    for (i = 0; i < NOBST; ++i) {
        tc_x = obst[i].x;
        tc_z = obst[i].z;
        if (to_camera())
            draw_model(obst[i].ang, &models[obst[i].model]);
    }

    if (edead) {
        evis = 0;
        tc_x = boomx;
        tc_z = boomz;
        if (to_camera()) {
            build_debris();
            draw_model(boomang, &debris_model);
        }
    } else {
        tc_x = ex;
        tc_z = ez;
        evis = to_camera();
        if (evis) {
            ecx = ccx;
            ecz = ccz;
            draw_model(eang, &models[M_TANK]);
        }
    }

    if (pshell.on) {
        tc_x = pshell.x;
        tc_z = pshell.z;
        if (to_camera())
            draw_model(pshell.ang, &shell_model);
    }
    if (eshell.on) {
        tc_x = eshell.x;
        tc_z = eshell.z;
        if (to_camera())
            draw_model(eshell.ang, &shell_model);
    }

    if (pdead) {
        draw_cracks();
        if (gameover) {
            fbtext(11, 9, "GAME OVER");
            if (pdead > 60) fbtext(11, 16, "PRESS FIRE");
        }
    }

    clipy = 0;
    draw_radar();
    clipy = VTOP;
}

#ifdef BENCH
/* time 32 repeats of each stage, in VDP ticks, and show the results */
static const char *blbl[16];
static unsigned char bres[16], brow;
static unsigned char bt, bk;
#define BENCHIT(label, code) \
    bt = TICKS; for (bk = 0; bk < 32; ++bk) { code; } bt = TICKS - bt; \
    blbl[brow] = label; bres[brow] = bt; ++brow;

static void bench(void)
{
    unsigned char i;
    ps = FSIN(ph); pc = FCOS(ph);
    BENCHIT("EMPTY", ;)
    BENCHIT("GFXINIT", gfx_init())
    BENCHIT("MOUNTAINS", draw_mountains(); gfx_init())
    BENCHIT("TOCAMERA", for (i = 0; i < NOBST; ++i) { tc_x = obst[i].x; tc_z = obst[i].z; to_camera(); })
    BENCHIT("TANK", tc_x = ex; tc_z = ez; to_camera(); draw_model(eang, &models[M_TANK]); gfx_init())
    BENCHIT("RADAR", draw_radar(); gfx_init())
    BENCHIT("BLITEMPTY", gfx_blit())
    BENCHIT("MOVE", move_player(); move_enemy())
    BENCHIT("RENDER", render(); gfx_init())
    gfx_init();
    gfx_blit();
    BENCHIT("FRAME", render(); gfx_blit())
    for (i = 0; i < brow; ++i) {
        vtext(0, i + 5, blbl[i]);
        vtext(12, i + 5, num(bres[i], 3));
    }
    for (;;) ;
}
#endif

int main(void)
{
    unsigned char i, last;

    init_screen();
    init_world();
    input_init();

#ifdef BENCH
    bench();
#endif
#ifdef TESTPAT
    /* line drawing test pattern: starburst, box and horizon */
    for (i = 0; i < 64; ++i) {
        cx0 = CENTREX; cy0 = 112;
        cx1 = CENTREX + smul(120, SIN(i << 2));
        cy1 = 112 - smul(78, COS(i << 2));
        drawline();
    }
    hline(0, HORIZON, 255, HORIZON);
    hline(10, 40, 245, 40); hline(245, 40, 245, 185);
    hline(245, 185, 10, 185); hline(10, 185, 10, 40);
    gfx_blit();
    for (;;) ;
#endif

    last = TICKS;
    for (;;) {
        i = TICKS;
        dt = i - last;
        last = i;
        ++frames;
        if (dt == 0) dt = 1;
        if (dt > 6) dt = 6;

        move_player();
        move_shells();
        move_enemy();
        render();
        gfx_blit();
        update_hud();
    }
}
