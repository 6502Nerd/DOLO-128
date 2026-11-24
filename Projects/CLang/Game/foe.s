.include "../hb128/hb128.inc"

FOES=14

.export _move_foes,_init_foe_type,init_foe_type

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import popa
.import _spr_x,_spr_y,_spr_pat,_spr_col
.import _scroll
.import _y_sin,_x_cos
.import _p_x,_p_y,_p_dx,_p_dy,_p_fx,_p_fy,_p_vx,_p_vy
.import _foe_xl,_foe_xh,_foe_y,_foe_pat1,_foe_pat2,_foe_col1,_foe_col2
.import _foe_data1,_foe_data2,_foe_counter,_foe_dx,_foe_dy,_foe_counter
.import _foe_state,_foe_vecl,_foe_vech;
.import _foe_snd

.segment "DATA"
foeVecl:
    .byte $00
    .byte <_foe_dying
    .byte <_foe_updown
    .byte <_foe_line
    .byte <_foe_wave
    .byte <_foe_circle
foeVech:
    .byte $00
    .byte >_foe_dying
    .byte >_foe_updown
    .byte >_foe_line
    .byte >_foe_wave
    .byte >_foe_circle


.segment "BSS"
foeVec:
    .res 2
foeDist:
    .res 2


.segment  "CODE"

_init_foe_type:         ; index,type
    pha
    jsr popa            ; Get index
    tax                 ; Put foe index in X
    pla
init_foe_type:          ; Use this for internal calls - x and a already set!
    tay                 ; index into vector table
    sta _foe_state,x
    lda foeVecl,y
    sta _foe_vecl,x
    lda foeVech,y
    sta _foe_vech,x
    rts

_move_foes:
    stz _foe_snd        ; Assume no foes in range
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
    jsr foe_sprite      ; Preserve x,y **
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
    sec
    lda foeDist
    sbc #128            ; 2 pixels per unit
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
    inc _foe_snd            ; The more foes on screen, the higher the wailing!
foe_offscreen:
    rts

_foe_dying:
    jsr _foe_anim           ; Just do die anim
    bcs remove_foe          ; If anim done then foe finished
    rts
remove_foe:
    lda #$e0
    sta _foe_y,x
    lda #0
    phy
    jsr init_foe_type
    ply
    rts

_foe_updown:
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
    jmp _foe_anim

_foe_line:
    ; add or subtract dx
    lda _foe_dx,x
    bmi foe_line_left
    clc
    adc _foe_xl,x
    sta _foe_xl,x
    lda _foe_xh,x
    adc #0
    and #3
    sta _foe_xh,x
    jmp _foe_anim
foe_line_left:
    clc
    lda _foe_xl,x
    adc _foe_dx,x
    sta _foe_xl,x
    lda _foe_xh,x
    adc #$ff
    and #3
    sta _foe_xh,x
    jmp _foe_anim

_foe_wave:
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
    jmp _foe_line

_foe_circle:
    lda _foe_data2,x
    inc a
    and #$7f
    sta _foe_data2,x
    phy
    tay
    clc
    lda _foe_data1,x
    adc _y_sin,y
    sta _foe_y,x
    lda _x_cos,y

    cmp #128
    ror a
    cmp #128
    ror a
    cmp #128
    ror a
    cmp #128
    ror a

    sta _foe_dx,x
    ply
    jmp _foe_line

_foe_anim:
    dec _foe_counter,x
    bne foe_skip_anim
    lda #8
    sta _foe_counter,x
    lda _foe_pat1,x
    inc a
    and #%11111011
    sta _foe_pat1,x
    clc
    adc #4
    sta _foe_pat2,x
    and #3              ; If bottom bits==0
    bne foe_skip_anim
    sec                 ; Then C=1 to indicate anim frame done
    rts
foe_skip_anim:
    clc                 ; C=0 anim frame not actioned / done
    rts
