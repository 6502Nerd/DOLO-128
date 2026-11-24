.include "../hb128/hb128.inc"

FOES=14

.export _check_collision
.export playerHit

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import _spr_x,_spr_y
.import _laser_pat,_laser_ptrh,_laser_ptrl,_laser_x,_laser_dx,_laser_y
.import _foe_pat1,_foe_pat2,_foe_counter
.import _p_x,_p_y
.import _foe_state,init_foe_type

.segment "BSS"
playerHit:
    .res 1
playerLeft:
    .res 2
playerTop:
    .res 1
foeDx:
    .res 2
foeDy:
    .res 1

.segment  "CODE"

_check_collision:
    stz playerHit
    ; Calculate box left of player (px+1)
    lda _p_x
    inc a
    sta playerLeft
    ; Calculate box top of player
    lda _p_y
    inc a
    sta playerTop
    ldx #FOES-1         ; X = index into foe tables
    ldy #30             ; Y = index into sprite tables
collision_loop:
    lda _foe_state,x    ; If foe state is 0 don't process
    beq next_foe
    cmp #1              ; Or if 1 because that is anyway dying
    beq next_foe
    lda _spr_y,y
    cmp #$e0            ; Sprite off screen?
    beq next_foe
    sec
    lda playerLeft      ; How close is x-coord
    sbc _spr_x,y
    bmi checkToLeft
    cmp #8              ; >=8 pixels
    bcs next_foe        ; No collision
    bcc check_dy
checkToLeft:
    cmp #(256-6)        ; <-6 pixels
    bcc next_foe        ; No collision
check_dy:
    sec
    lda playerTop       ; How close is y-coord
    sbc _spr_y,y
    bmi checkToTop
    cmp #8             ; >=8 pixels
    bcs next_foe        ; No collision
    bcc collision
checkToTop:
    cmp #(256-13)        ; <-13 pixels
    bcc next_foe        ; No collision
collision:
    inx
    stx playerHit
    dex
next_foe:
    jsr check_laser_hit
    bcc no_laser_hit
    ; Foe was hit!
    ; Set pattern to explode
    lda #32
    sta _foe_pat1,x
    lda #36
    sta _foe_pat2,x
    ; Anim counter
    lda #8
    sta _foe_counter,x
    lda #1
    phy
    jsr init_foe_type
    ply
no_laser_hit:
    dey
    dey
    dex
    bpl collision_loop
    rts

check_laser_hit:
    phx
    ldx #7
do_laser_loop:
    lda _laser_dx,x
    beq next_laser
    lda _laser_x,x
    asl a
    asl a
    asl a
    sec
    sbc _spr_x,y
    bmi laserLeft
    cmp #8
    bcs next_laser
    bcc check_laser_y
laserLeft:
    cmp #(256-8)
    bcc next_laser   
check_laser_y:
    lda _laser_y,x
    sec
    sbc _spr_y,y
    bmi laser_top
    cmp #8
    bcs next_laser
    bcc do_laser_hit
laser_top:
    cmp #(256-8)
    bcc next_laser

do_laser_hit:
    lda #0
    sta _laser_dx,x
    plx
    sec
    rts

next_laser:
    dex
    bpl do_laser_loop
    plx
    clc
    rts
