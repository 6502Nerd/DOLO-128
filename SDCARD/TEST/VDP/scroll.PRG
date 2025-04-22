def_test()
 mode 1
 dim code[200]

def_asm(o)
 .opt o:.org code
 .buff:.ds 32
 .normal


110 def_demo(screenMode)
111 iframe=23381
112 idelay=2664
130 dim code$[200,5]
150 cursor 0
170 osvwrreg=0xc001+3*2
180 VIA1=0x0480
190 mode screenMode:cursor 1:for y=0,23,1:plot y,y,"6502 Nerd":next
210 _asm(0):_asm(0):_asm(3)
220 doke frame,iframe:doke delay,idelay
230 .opt 1
250 enddef
270 ;
290 def_asm(option)
310 .opt option:.org code$
330 ;
350 .colour:.ds 1
370 .osvdp:.ds 2
380 .osvvia1:.ds 2
385 .delay:.ds 2
386 .frame:.ds 2
387 vdpvec=8:via1timervec=12
390 ;
410 .init
430 sei:lda vdpvec:sta osvdp:lda vdpvec+1:sta osvdp+1
450 lda #vdpint&255:sta vdpvec:lda #vdpint>>8:sta vdpvec+1
460 lda via1timervec:sta osvvia1:lda via1timervec+1:sta osvvia1+1
470 lda #timerint&255:sta via1timervec:lda #timerint>>8:sta via1timervec+1
480 lda #0b11000000:sta VIA1+14
490 cli:rts
510 ;
530 .timerint
540 lda delay:sta VIA1+4:lda delay+1:sta VIA1+5
550 ldx colour:inx:stx colour
560 cpx #0xef:beq timerdone
570 lda #7:jsr osvwrreg
590 rts
600 .timerdone:lda #0b01000000:sta VIA1+14:ldx #0xfe:lda #7:jmp osvwrreg
610 ;
620 .vdpint
630 lda frame:sta VIA1+4:lda frame+1:sta VIA1+5
635 lda #0b11000000:sta VIA1+14
640 lda #0xe0:sta colour
650 rts
810 ;
830 .restore
850 sei:lda osvdp:sta vdpvec:lda osvdp+1:sta vdpvec+1
860 lda osvvia1:sta via1timervec:lda osvvia1+1:sta via1timervec+1
865 lda #0b01000000:sta VIA1+14
870 cli:rts
890 enddef

