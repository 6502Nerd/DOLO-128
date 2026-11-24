MAX_SPRITES=32

.include "../hb128/hb128.inc"

.export _vb_handler

.import _tileDef, _superTileDef, _superTileMap
.import _int_delay, _scrBuf
.import _int_invoked, _int_render,_int_sprite
.import _sprb_x, _sprb_y, _sprb_pat, _sprb_col,_p_dy,_p_y,playerHit,_p_hit

.import _p_dx,_p_x,_p_x,_mapS,_mapX

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

    ldx #0                      ; 4 sprites of player goes first
    jsr vbint_write_sprite
    inx
    jsr vbint_write_sprite
    inx
    jsr vbint_write_sprite
    inx
    jsr vbint_write_sprite
    inx
    lda _int_invoked            ; Use this to determine rotation point
    asl a
    and #31
    bne skip_wrap1
    lda #4
skip_wrap1:
    tax
    ldy #MAX_SPRITES-4          ; Player sprites already drawn
spr_rot_loop:
    jsr vbint_write_sprite
    inx
    txa
    and #31
    bne skip_wrap2
    lda #4
skip_wrap2:
    tax
    dey
    bne spr_rot_loop
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
    lda _mapX
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay
    lda _mapS
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay

    lda #$20
    jsr vbint_write_delay
    jsr vbint_write_delay
    lda _p_x
    jsr AtoX
    jsr vbint_write_delay
    txa
    jsr vbint_write_delay
    lda _p_y
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
