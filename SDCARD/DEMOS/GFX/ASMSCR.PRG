95 ; Testing scrolling routine using
96 ; assembly. Very slow!
100 def_demo()
105 mode 1
110 dim code$[255,2]
115 for y=16,23,1:for x=0,31,1
120 plot x,y,x+(y-16)*32
130 next:next
131 _asm(0):_asm(0)
132 _asm(3)
140 enddef
1000 def_asm(option)
1001 start=0x0000+128*8
1002 osvrdaddr=0xc001+3*8
1003 osvwraddr=0xc001+3*7
1004 vdpvram=0x0500
1005 size=128
1006 ptr=0x8e
1010 .opt option:.org code$
1011 .temp:.ds size
1013 .row:.ds 1
1014 .base:.ds 2
1100 .scroll
1110 lda #8
1120 sta row
1121 lda #start&255
1122 sta base
1123 lda #start>>8
1124 sta base+1
1125 sei
1130 .read
1140 _initPtrRd()
1180 ldy #0
1190 .readRow
1195 _delay()
1220 lda vdpvram
1230 sta temp,y
1231 nop
1235 _incPtrRd()
1240 iny
1245 cpy #size
1250 bne readRow
1260 lda temp
1270 cmp #128
1275 ldx #size-1
1280 .shiftRow
1290 rol temp,x
1300 dex
1310 bpl shiftRow
1320 _initPtrWr()
1330 ldy #0
1340 .writeRow
1347 lda temp,y
1390 sta vdpvram
1391 _delay()
1400 _incPtrWr()
1420 iny
1425 cpy #size
1430 bne writeRow
1431 clc
1432 lda base
1433 adc #1
1434 sta base
1435 lda base+1
1436 adc #0
1437 sta base+1
1440 dec row
1450 beq done
1455 jmp read
1456 .done
1457 cli
1460 rts
1470 enddef
1480 def_initPtrRd()
1490 ldx base:stx ptr
1510 lda base+1:sta ptr+1
1520 jsr osvrdaddr
1530 enddef
1540 def_initPtrWr()
1550 ldx base:stx ptr
1560 lda base+1:sta ptr+1
1570 jsr osvwraddr
1580 enddef
1590 def_incPtrRd()
1600 clc:lda ptr:adc #8:sta ptr:tax
1610 lda ptr+1:adc #0:sta ptr+1
1615 jsr osvrdaddr
1620 enddef
1630 def_incPtrWr()
1640 clc:lda ptr:adc #8:sta ptr:tax
1650 lda ptr+1:adc #0:sta ptr+1
1660 jsr osvwraddr
1670 enddef
1680 def_delay()
1690 nop:nop:nop:nop
1700 enddef

