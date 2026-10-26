.include "../hb128/hb128.inc"

FOES=14

.export _move_foes,_foe_simple,_foe_static
.export foeDist2

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import _spr_x,_spr_y,_spr_pat,_spr_col
.import _scroll
.import _y_sin
.import _p_x,_p_y,_p_dx,_p_dy,_p_fx,_p_fy,_p_vx,_p_vy
.import _foe_xl,_foe_xh,_foe_y,_foe_pat1,_foe_pat2,_foe_col1,_foe_col2,_foe_data1,_foe_data2,_foe_counter
.import _foe_state,_foe_vecl,_foe_vech;

.segment "BSS"
foeVec:
    .res 2
foeDist:
    .res 2
foeDist2:
    .res 2


.segment  "CODE"

_move_foes:
    ldx #FOES-1         ; X = index into foe tables
    ldy #30             ; Y = index into sprite tables
foe_loop:
    lda #$e0            ; Put sprite off screen initially
    sta _spr_y,y
    sta _spr_y+1,y
    lda _foe_vech,x     ; If foe vec high is 0 don't process
    beq next_foe
    sta foeVec+1
    lda _foe_vecl,x
    sta foeVec
    jsr process_foe     ; Remember to preserve X,Y ********
next_foe:
    dey
    dey
    dex
    bpl foe_loop 
    rts

process_foe:
    jmp (foeVec)

foe_sprite:
    ; Check if on screen : scroll - foe_xlh
    ; 
    sec
    lda _foe_xl,x
    sbc _scroll
    sta foeDist
    lda _foe_xh,x
    sbc _scroll+1
    bpl foe_checkinrange
    clc
    adc #4
foe_checkinrange:
    sta foeDist+1
    cpx #0
    bne skip_save
    lda foeDist
    sta foeDist2
    lda foeDist+1
    sta foeDist2+1
skip_save:
    sec
    lda foeDist
    sbc #128
    lda foeDist+1
    sbc #0
    bpl foe_offscreen
    lda foeDist
    ; If on screen then write to sprite tables
    asl a
    sta _spr_x,y
    sta _spr_x+1,y
    lda _foe_y,x
    sta _spr_y,y
    sta _spr_y+1,y
    lda _foe_pat1,x
    sta _spr_pat,y
    lda _foe_pat2,x
    sta _spr_pat+1,y
    lda _foe_col1,x
    sta _spr_col,y
    lda _foe_col2,x
    sta _spr_col+1,y
foe_offscreen:
    rts

_foe_simple:
    ; just move the foe forward 1 pixel
    inc _foe_xl,x
    bne skip_xh
    lda _foe_xh,x
    inc a
    and #3
    sta _foe_xh,x
_foe_wavey:
    lda _foe_data2,x
    inc a
    and #$7f
    sta _foe_data2,x
    phy
    tay
    clc
    lda _foe_data1,x
    adc _y_sin,y
    ply
    sta _foe_y,x

_foe_anim:
    dec _foe_counter,x
    bne foe_skip_anim
    lda #8
    sta _foe_counter,x
    lda _foe_pat1,x
    inc a
    and #%00010011
    sta _foe_pat1,x
    clc
    adc #4
    sta _foe_pat2,x
foe_skip_anim:
    jmp foe_sprite
skip_xh:
_foe_static:
    jmp _foe_wavey
