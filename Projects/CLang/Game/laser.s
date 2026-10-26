.include "../hb128/hb128.inc"


.export _move_laser

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import popa, popax, popptr1, pushax

.import _laser_x,_laser_y,_laser_dx,_laser_pat,_laser_ptrl,_laser_ptrh,_scrBuf
.import _scrn_off_l,_scrn_off_h

.segment "BSS"
scrIndex:
    .res 1
mapIndex:
    .res 1

.segment  "CODE"
_move_laser:
    ldx #7
do_laser_loop:
    lda _laser_dx,x
    beq next_laser
    clc
    adc _laser_x,x
    bmi laser_off
    cmp #32
    bcs laser_off
    sta _laser_x,x
    tay
    lda _laser_ptrl,x
    sta ptr1
    lda _laser_ptrh,X
    sta ptr1+1
    lda _laser_pat,x
    sta (ptr1),y
    bra next_laser
laser_off:
    stz _laser_dx,x
next_laser:
    dex
    bpl do_laser_loop
    rts
