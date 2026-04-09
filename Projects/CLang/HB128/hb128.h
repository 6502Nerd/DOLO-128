#ifndef _HB128_H_
#define _HB128_H_

extern void dfcl_mode(unsigned char mode);
extern void dfcl_colour(unsigned char reg, unsigned char fg, unsigned char bg);
extern void dfcl_line(unsigned char x1, unsigned char y1, unsigned char x2, unsigned char y2);
extern void dfcl_circle(unsigned char x, unsigned char y, unsigned char r);
extern void dfcl_box(unsigned char x1, unsigned char y1, unsigned char x2, unsigned char y2);
extern void dfcl_cls();
extern void dfcl_plot(unsigned char x, unsigned char y, unsigned char c);
extern unsigned char dfcl_scrn(unsigned char x, unsigned char y);
extern void dfcl_gotoxy(unsigned char x, unsigned char y);

extern void dfcl_ptinit(unsigned char *ptr,unsigned char loop);
extern void dfcl_ptrun(unsigned char state);
extern void dfcl_ptstop();
extern char dfcl_ptload(char *fname, unsigned char *ptr);

extern void dfcl_sprpat(unsigned char nme, unsigned char *pat);
extern void dfcl_sprpos(unsigned char spr, unsigned char x, unsigned char y);
extern void dfcl_sprcol(unsigned char spr, unsigned char col);
extern void dfcl_sprnme(unsigned char spr, unsigned char nme);

extern char dfcl_chdir(char *dir);
extern char dfcl_vload(char *fname, unsigned int vaddr);
extern char dfcl_font(char *fname);
extern char dfcl_bload(char *fname, unsigned int vaddr);
#endif // _HB128_H_
