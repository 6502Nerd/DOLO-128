MAX_SPRITES=32

.include "../hb128/hb128.inc"

.export _vb_handler

.import _tileDef, _superTileDef, _superTileMap
.import _int_c, _int_v, _scrBuf
.import _spr_x, _spr_y, _spr_pat, _spr_col

.segment  "CODE"

.macro vdp_line addr
    .local vdp_byte
    ldy #0
vdp_byte:
    lda addr,y
    sta _dfcl0_VDP_VRAM
    iny
    cpy #32
    bne vdp_byte
.endmacro

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
    nop
    rts

vbint_write_sprite:
    lda _spr_y,x                ; Write attribute table
    jsr vbint_write_delay
    lda _spr_x,x
    jsr vbint_write_delay
    lda _spr_pat,x
    jsr vbint_write_delay
    lda _spr_col,x
    jsr vbint_write_delay
    rts

vbint_sprites:
    ; Update sprite positions
    
    vdp_wr_addr $3b00           ; Mode 2 sprite attribute table

    inc _int_c                  ; Alternate starting point
    lda _int_c
    and #1
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
    lda _int_v
    bne do_vdp_int
    rts

do_vdp_int:
    vdp_wr_reg 7,$11        ; Border to black

    jsr vbint_sprites

    vdp_wr_addr $3800       ; Mode 2 screen address

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

vdp_done:
    ; Signify done
    lda #0
    sta _int_v

    vdp_wr_reg 7,$66           ; Border to red

    rts
