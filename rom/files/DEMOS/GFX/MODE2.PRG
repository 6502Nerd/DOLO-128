95 ; Testing mode 2 which allows
96 ; 8x1 colour for each 8x8
97 ; character.
100 def_demo()
110  mode 2
115  setvdp 7,0x11
120  for x=0x3900,0x39ff,1
130    vpoke x,x
140  next
150  for c=0,2047,1
160   if (c<256)|(c>263)
170    v=((c\14)+2)*16+1
180   else
190    v=0x11
200   endif
220   vpoke 0x2000+c,v
240  next
300 enddef

