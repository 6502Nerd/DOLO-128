.include "../hb128/hb128.inc"

PLAYER_XSPEED=2

.export _move_player

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import popa, popax, popptr1, pushax

.import _spr_x,_spr_y,_spr_pat,_x_coord,_y_coord
.import _sprite_space,_scroll
.import _scrn_off_l,_scrn_off_h
.import _tileHit

.import _p_x,_p_y,_p_dx,_p_ddx,_p_ddy,_p_dy,_p_fx,_p_fy,_p_vx,_p_vy,_p_ex,_p_ey,_p_spr,_p_hit

.import _laser_x,_laser_y,_laser_dx,_laser_pat,_laser_ptrl,_laser_ptrh,_scrBuf

.import _dfcl_stick

.segment "BSS"
fireDebounce:
    .res 1
tmplaserptr:
    .res 1
mapIndex:
    .res 1

.segment  "CODE"
do_player_gravity:
    clc
    lda _p_dy
    inc a
    bmi nody_adjust
    cmp #8
    bcc nody_adjust
    lda #7
nody_adjust:
    sta _p_dy
    cmp #128
    ror a
    cmp #128
    ror a
    clc
    adc _p_y
    cmp #(18*8+1)
    bcs skip_py_adjust
    sta _p_y
skip_py_adjust:
    rts   

do_player_physics:
    ; Acceleration += jerk
    ; dx += ddx
    clc
    lda _p_dx
    adc _p_ddx
    tax
    and #%11100000
    cmp #%10000000
    bne check_dx_upper
    ldx #%10100000
check_dx_upper:
    cmp #%01100000
    bne clamp_dx
    tax
clamp_dx:
    stx _p_dx    
skip_dx_adjust:    
    ; vx += dx
    clc
    lda _p_vx
    tax
    adc _p_dx
    sta _p_vx
    lda #%01100000
    bvc skip_vx_adjust
    cpx #0
    bpl clamp_vx
    eor #%11111111
clamp_vx:
    sta _p_vx
skip_vx_adjust:
    ; Get bit 6,5 of velocity in to 1,0
    lda _p_vx
    asl a
    rol a
    rol a
    rol a
    ldx _p_vx
    bmi do_neg_vx
pos_vx:
    and #3
    sta _p_ex
    stz _p_ex+1
    lda _p_vx
    and #%10011111
    sta _p_vx
    bra update_scroll
do_neg_vx:
    ; tricky when   111 (-1) = 100 (0)
    ;               110 (-2) = 111 (-1)
    ;               101 (-3) = 110 (-2)
    ;               100 (-4) = 101 (-3)
    ; so take lsb and add 1
    ; if zero then positive ex
    inc a
    and #3
    bne ex_zero_skip
    sta _p_ex
    sta _p_ex+1
    bra ex_update_vx
ex_zero_skip:
    ora #%11111100
    sta _p_ex
    lda #%11111111
    sta _p_ex+1
ex_update_vx:
    lda _p_vx
    ora #%01100000
    sta _p_vx
update_scroll:
    ; Now check where are we in the screen buffer
    ldy #16             ; Player is in the middle facing right
    lda _p_ex+1         ; Unless facing left!
    bpl skip_left_facing
    ldy #16
skip_left_facing:
    lda _p_y            ; Get char row from y pos
    clc                 ; Add 3 pixels for rounding
    adc #3
    lsr a
    lsr a
    lsr a
    tax
    clc
    lda #<_scrBuf
    adc _scrn_off_l,x
    sta ptr1
    lda #>_scrBuf
    adc _scrn_off_h,x
    sta ptr1+1
    lda (ptr1),y
    tax
    lda _tileHit,x
    asl a
    asl a
    asl a
    asl a
    sta _p_hit
check_next_row:
    tya                     ; Check next row
    clc
    adc #32
    tay
    lda (ptr1),y
    tax
    lda _tileHit,x
    ora _p_hit
    sta _p_hit
    beq no_collision
collision:
    stz _p_dx           ; No residual x velocity
    stz _p_dy
    rts
no_collision:
    ; Add to scroll value, clamp to 0-1023
    clc
    lda _scroll
    adc _p_ex
    tax
    lda _scroll+1
    adc _p_ex+1
    and #%00000011
    sta _scroll+1
    txa
    sta _scroll
    rts

do_player_friction:
    lda _p_dx
    beq skip_friction
    bmi friction_neg
    dec _p_dx
    rts
friction_neg:
    inc _p_dx
skip_friction:
    rts

_move_player:
    ; Assume no jerk
    stz _p_ddx
    stz _p_ddx+1
    stz _p_ddy
    stz _p_ddy+1

    ; Player sprite in rest position
    lda _p_spr
    and #7
    sta _p_spr

    jsr check_stick
    jsr do_player_gravity
    jsr do_player_friction
    jsr do_player_physics

    ; Adjust x pos from middle based on velocity
;    lda _p_dx
;    php
;    lsr a
;    lsr a
;    plp
;    bpl skip_p_dx_minus
;    ora #$c0
;skip_p_dx_minus:
;    clc
;    adc #128
;    sta _p_x

    ; Update spaceman sprites (4)
    ; xpos same for all
    lda _p_x
    sta _spr_x
    sta _spr_x+1
    sta _spr_x+2
    sta _spr_x+3
    ; ypos for 0,2 add 8 for 1,3
    lda _p_y
    dec a
    sta _spr_y
    sta _spr_y+2
    clc
    adc #8
    sta _spr_y+1
    sta _spr_y+3
    ; Pattern dependent on player move
    lda _p_spr
    sta _spr_pat
    inc a
    sta _spr_pat+1
    inc a
    inc a
    inc a
    sta _spr_pat+2
    inc a
    sta _spr_pat+3
    rts

check_stick:
    lda #$ff
    jsr _dfcl_stick
    bit #128
    bne check_firedebounce
    stz fireDebounce
    beq skip_dofire
check_firedebounce:
    ldx fireDebounce
    bne skip_dofire
    sta fireDebounce        ; Because A is not zero!
    pha
    jsr do_fire
    pla
skip_dofire:
    bit #64
    bne move_left
    bit #32
    bne move_right
check_updown:
    bit #16
    bne move_up
    bit #8
    bne move_down
    rts

move_left:
    ldx #(256-PLAYER_XSPEED)
    stx _p_ddx
    ldx #$ff
    stx _p_ddx+1
    ldx #2+8
    stx _p_spr
    bra check_updown

move_right:
    ldx #PLAYER_XSPEED
    stx _p_ddx
    stz _p_ddx+1
    ldx #0+8
    stx _p_spr
    bra check_updown

move_up:
    sec
    lda _p_dy
    sbc #2
    bpl skip_dy_lower
    cmp #(256-8)
    bcs skip_dy_lower
    lda #(256-7)
skip_dy_lower:
    sta _p_dy
    rts

move_down:
    clc
    lda _p_dy
    adc #2
    bmi skip_dy_upper
    cmp #8
    bcc skip_dy_upper
    lda #7
skip_dy_upper:
    sta _p_dy
    rts

do_fire:
    ldx #0
find_laser_slot:
    lda _laser_dx,x
    beq found_laser_slot
    inx
    cpx #8
    bne find_laser_slot
    rts
found_laser_slot:
    ; Store x coord as byte offset
    lda _p_x
    lsr a
    lsr a
    lsr a
    sta _laser_x,x

    ; Store y coord as byte offset
    ; also calculate pointer
    lda _p_y
    lsr a
    lsr a
    lsr a
    inc a
    sta _laser_y,x
    tay
    clc
    lda _scrn_off_l,y
    adc #<_scrBuf
    sta _laser_ptrl,x
    lda _scrn_off_h,y
    adc #>_scrBuf
    sta _laser_ptrh,x

    ; Store which pattern to use - 0,1,2,3
    lda _p_y
    lsr a
    and #3
    sta _laser_pat,x

    ; Store the direction
    ; Based on which way player is facing
    ldy #1
    lda _p_spr
    and #2
    beq skip_laser_left
    ldy #$ff
skip_laser_left:
    tya
    sta _laser_dx,x

    rts

