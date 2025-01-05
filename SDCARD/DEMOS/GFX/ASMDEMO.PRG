100 def_asm(option)
110 .opt option:.org code$
130 .x:.ds 1
150 .y:.ds 1
170 .init:sei
181 lda 6:sta osvdp+1
183 lda 7:sta osvdp+2
190 lda #vblank and 255:sta 6
220 lda #vblank >> 8:sta 7
230 cli:rts
250 .vblank:inc x:lda x
281 ldy #0x13:ldx #0x01:jsr 0xc00a
284 .osvdp:.mp 0xffff:.ts
300 .restore:.ei
320 lda osvdp+1:sta 6
340 lda osvdp+2:sta 7
360 cli:rts
380 enddef
400 def_demo(r,xpos,ypos)
405 dim code$[200]
410 mode 1
420 sprite 0,xpos,ypos,1,0x0f
430 poke x,xpos:poke y,ypos
440 _asm(0):_asm(0)
450 _asm(2+1)
460 if r:r=call(init,0,0,0):endif
500 enddef

