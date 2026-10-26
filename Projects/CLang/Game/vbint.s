MAX_SPRITES=32

.include "../hb128/hb128.inc"

.export _vb_handler

.import _tileDef, _superTileDef, _superTileMap
.import _int_c, _int_delay, _scrBuf
.import _int_invoked, _int_render,_int_sprite
.import _sprb_x, _sprb_y, _sprb_pat, _sprb_col,_p_dy,_p_y,_p_hit

.import _p_dx,_p_x

.segment  "CODE"

.macro vdp_wr_addr addr
    ldx #<addr
	stx _dfcl0_VDP_MODE1
	nop
	nop
    nop
    ldx #(>addr)|$40    ; 0x40 required by VDP
	stx _dfcl0_VDP_MODE1
.endmacro

.macro vdp_wr_reg reg, val
    lda #val
    sta _dfcl0_VDP_MODE1
    nop
    nop
    nop
    lda #reg|$80                ; Register + 0x80
    sta _dfcl0_VDP_MODE1
.endmacro

vbint_write_delay:
    sta _dfcl0_VDP_VRAM
    rts

vbint_write_sprite:
    lda _sprb_y,x                ; Write attribute table
    dec a
    jsr vbint_write_delay
    lda _sprb_x,x
    jsr vbint_write_delay
    lda _sprb_pat,x
    jsr vbint_write_delay
    lda _sprb_col,x
    jsr vbint_write_delay
    rts

vbint_sprites:
;    lda _int_sprite
;    beq do_sprites
;    rts
do_sprites:
    ; Update sprite positions
    
    vdp_wr_addr $3b00           ; Mode 2 sprite attribute table

    inc _int_c                  ; Alternate starting point
    lda _int_c
    and #3
    cmp #1
    beq spr_reverse
    cmp #2
    beq spr_middle
    cmp #3
    beq spr_middle_rev
    ldx #0
spr_forward_loop:
    jsr vbint_write_sprite
    inx
    cpx #MAX_SPRITES
    bne spr_forward_loop
    rts

spr_reverse:
    ldx #(MAX_SPRITES-1)
spr_reverse_loop:
    jsr vbint_write_sprite
    dex
    bpl spr_reverse_loop
    rts

spr_middle:
    ldx #0
spr_middle_loop1:
    jsr vbint_write_sprite
    inx
    cpx #(MAX_SPRITES/2)
    bne spr_middle_loop1
    ldx #MAX_SPRITES-1
spr_middle_loop2:
    jsr vbint_write_sprite
    dex
    cpx #(MAX_SPRITES/2)
    bne spr_middle_loop2
    rts

spr_middle_rev:
    ldx #MAX_SPRITES-1
spr_middle_rev_loop1:
    jsr vbint_write_sprite
    dex
    cpx #(MAX_SPRITES/2)
    bne spr_middle_rev_loop1
    ldx #0
spr_middle_rev_loop2:
    jsr vbint_write_sprite
    inx
    cpx #(MAX_SPRITES/2)
    bne spr_middle_rev_loop2
    rts

_vb_handler:
    vdp_wr_reg 7,$66           ; Border to red

    jsr vbint_sprites

    inc _int_invoked
    bne skip1
    inc _int_invoked+1
skip1:

    lda _int_delay
    beq skip_renderer
    dec _int_delay
    beq do_vdp_int
skip_renderer:
    vdp_wr_reg 7,$11           ; Border to black
    rts

do_vdp_int:
    inc _int_render
    bne skip2
    inc _int_render+1
skip2:

    vdp_wr_addr $3800       ; Mode 2 screen address lines

    ; Copying 32*8 lines = 256 bytes
    ldy #0
vdp_byte1:
    lda _scrBuf,y
    sta _dfcl0_VDP_VRAM
    nop
    nop
    iny
    bne vdp_byte1
    ; Copying next 32*8 lines = 256 bytes
vdp_byte2:
    lda _scrBuf+$100,y
    sta _dfcl0_VDP_VRAM
    nop
    nop
    iny
    bne vdp_byte2

    ; Copying last 32*4 lines = 128 bytes
vdp_byte3:
    lda _scrBuf+$200,y
    sta _dfcl0_VDP_VRAM
    nop
    nop
    iny
    cpy #128
    bne vdp_byte3

    ; Write out diag counters
    lda _int_invoked+1
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay
    lda _int_invoked
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay

    lda #$20
    jsr vbint_write_delay
    jsr vbint_write_delay
    lda _int_render+1
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay
    lda _int_render
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay

    lda #$20
    jsr vbint_write_delay
    jsr vbint_write_delay

    lda _p_hit
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay
;    lda _p_dy
;    jsr AtoX
;    jsr vbint_write_delay
;    txa
;    jsr vbint_write_delay

    ; Finished
    vdp_wr_reg 7,$11        ; Border to black

    rts

AtoX:
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr nibbleToX
    tay
    pla
    and #$0f
    jsr nibbleToX
    tax
    tya
    rts

nibbleToX:
    ora #$30
    cmp #$3a
    bcc skipX
    adc #$06
skipX:
    rts
