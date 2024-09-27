 def_init()
  hires 0x11
  setvdp 1,0xe1
  vload 0,"snowman"
  for i=0,15,1
   read a
   vpoke 0x1800+i,a
  next
  dim scale[7]
  for i=1,7,1
    read scale[i]
  next
  dim m$[255], d$[100]
  m$=""
  repeat
    read d$
    m$=m$+d$
  until d$==""
  m=addr(m$)
 enddef
 data 0b00000000
 data 0b00010000
 data 0b01010100
 data 0b00111000
 data 0b01010100
 data 0b00010000
 data 0b00000000
 data 0b00000000
 ;
 data 0b10010010
 data 0b01010100
 data 0b00111000
 data 0b11111110
 data 0b00111000
 data 0b01010100
 data 0b10010010
 data 0b00000000
 ;
 ; scale letter start = A
 data 9,11,0,2,4,5,7
 ; Walking in the air
 ; Verse 1
 data "2A2^D2^D2^C2^C6A"
 data "2A2^D2^D2^C2^C6A2F6G"
 data "2G2Bb2Bb2A2A6G"
 data "2D2F2F2E2E6D"
 ; Verse 2
 data "2A2^D2^D2^C2^C6A"
 data "2A2^D2^D2^C2^C6A2F6G"
 data "2G2Bb2Bb2A2A6G"
 data "2D2F2F2E2E6D"
 ; 
 data "2^C#2^D2E42F2G4A"
; data B - ^C   ^D    B - G
; data D#-F-G      A      Bb-^C
; data A - ^D       ^C#     A
 data ""
 ;
 def_anim(n,d)
  reset t:t=rnd(t)
  dim x[32],y[32],dx[32],dy[32]
  for i=1,n,1
    x[i]=rnd(0)\200+25
    y[i]=rnd(0)\200+1
    dx[i]=rnd(0)\5-2
    dy[i]=rnd(0)\6+1
    sprite i-1,x[i],y[i],rnd(0)\2,rnd(0)\1+15
  next
  spritepos n,0,0xd0
  o=2:tempo=10:j=m
  nextNote=0
  reset timer
  repeat
    if elapsed(timer)>=nextNote
      reset timer
      nextNote = tempo*(peek(j)-'0')
      j=j+1
      o=2
      if peek(j)=='^'
        o=o+1
        j=j+1
      endif
      note=scale[peek(j)-64]
      if peek(j+1)=='#'
        note=note+1
        j=j+1
      elif peek(j+1)=='b'
        note=note-1
        j=j+1
      endif
      j=j+1
      if peek(j)==0
        j=m
      endif
      music 1,o,note,0
      play 1,0,1,4000
    endif
    for i=1,n,1
      x[i]=x[i]+dx[i]
      if x[i]<=10 | x[i]>=245
       dx[i]=0-dx[i]
      else
       if (rnd(0)\10)<1:dx[i]=0-dx[i]:endif
      endif
      y[i]=y[i]+dy[i]
      if y[i]>185:y[i]=1:dx[i]=rnd(0)\5-2:dy[i]=rnd(0)\6+1:endif
      spritepos i-1,x[i],y[i]
    next
  until 0
 enddef
 def_start()
  _init()
  _anim(13,1)
 enddef
