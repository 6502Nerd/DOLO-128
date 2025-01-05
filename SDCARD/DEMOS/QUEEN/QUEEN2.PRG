 def_start(slideDelay)
 _init()
  repeat
   a=0
   repeat
    a=a+1
    if f$[a]<>""
    if (f$[a]<>f$[a-1])|(a==1):vload 0,f$[a]:endif
     _initName(a)
     _animate(24,32,1)
     _twinkle(2)
     _animate(32,24,-1)
    endif
   until f$[a]==""
  until 0
 enddef
 ;
 def_initName(a)
  for i=0,len(n$[a]),1
   sprite i,0,8*i,asc(mid(n$[a],i+1,1)),0x80+15
  next
  spritepos i,0,0xd0
 enddef
 ;
 def_animate(x1,x2,dx)
  for j=x1,x2,dx
   for i=0,len(n$[a]),1
    spritepos i,j,i*8
   next
   wait 4
  next
 enddef
 ;
 def_twinkle(speed)
  for d=0,slideDelay,1:for j=0,31,1
  ; if d>(slideDelay/4):spritecol j,(j+d)\14+2+0x80:endif
  next:wait speed:next
 enddef
 ;
 def_init()
  hires 0x11
  a=0
  dim f$[10,40],n$[30,40]
  repeat
   a=a+1:read f$[a],n$[a]
  until f$[a]==""
 enddef
 ;
 data "queen", " * QUEEN ELIZABETH II * "
 data "queen", "    * 1926 - 2022 *     "
 data "queen", "   * THANK YOU MAAM *   "
 data "queen", "  * AND REST IN PEACE * "
 data "",""

