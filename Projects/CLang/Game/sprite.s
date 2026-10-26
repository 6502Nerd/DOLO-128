.include "../hb128/hb128.inc"

.export _spr_to_buf

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import _spr_x,_spr_y,_spr_pat,_spr_col
.import _sprb_y,_sprb_x,_sprb_pat,_sprb_col
.import _x_coord,_y_coord
.import _spr_cycle,_sprite_space
.import _p_x,_p_y,_p_dx,_p_dy,_p_fx,_p_fy,_p_vx,_p_vy
.import _int_sprite


.segment "BSS"
mapRowCount:
    .res 1
scrIndex:
    .res 1
mapIndex:
    .res 1

.segment  "CODE"

_spr_to_buf:
    ldy #31
sprbuf_loop:
    lda _spr_y,y
    sta _sprb_y,y
    lda _spr_x,y
    sta _sprb_x,y
    lda _spr_pat,y
    sta _sprb_pat,y
    lda _spr_col,y
    sta _sprb_col,y
    dey
    bpl sprbuf_loop
    rts
