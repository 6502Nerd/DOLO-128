; ---------------------------------------------------------------------------
; gfx.s - RAM framebuffer graphics for TMS9918 Graphics II (hires) mode
;
; The screen is drawn into a 6144 byte framebuffer in CPU RAM that has exactly
; the same layout as the VDP pattern table:
;     offset = (y>>3)*256 + (x & $F8) + (y & 7),  bit = $80 >> (x & 7)
;
; Each 8x8 cell has a dirty byte:
;     bit 0 = something was drawn in the cell this frame
;     bit 1 = the cell had something in it last frame (VRAM holds old pixels)
; gfx_blit copies every cell with a non-zero dirty byte to VRAM and clears the
; RAM copy as it goes, so the framebuffer is blank again for the next frame.
; Only cells that changed cost VDP time, and there is no blank/flicker phase.
;
; A second "background" buffer (BG) with the same layout holds things that
; never change (horizon, gun sight, radar ring). Draw into it by setting
; gfx_base = >BG before calling gfx_line (no dirty marking happens). Each
; copied cell is FB | BG, so the background costs nothing per frame.
; ---------------------------------------------------------------------------

.export _gfx_init, _gfx_line, _gfx_blit, _gfx_mark, _gfx_vput8, _gfx_src
.exportzp _lx0, _ly0, _lx1, _ly1, _gfx_base
.export _fb, _bg, _dirty

.import __BSS_RUN__, __BSS_SIZE__

VDP_DATA    = $0500
VDP_CTRL    = $0501

FB          = $A000         ; must match tank.cfg (FB memory area)
BG          = $7800         ; must match tank.cfg (BG memory area)
DIRTY       = $9C00         ; must match tank.cfg (DIRTY memory area)
FBHI        = >FB

; Make sure the C program never grows into the C stack / dirty map
.assert __BSS_RUN__ + __BSS_SIZE__ <= BG, lderror, "Program too big: BSS runs into the background buffer"

.segment "FBUF"
_fb:        .res 6144
.segment "BGBUF"
_bg:        .res 6144
.segment "DIRTYBUF"
_dirty:     .res 768

.segment "ZEROPAGE"
_lx0:       .res 1          ; line end points (set from C, then call gfx_line)
_ly0:       .res 1
_lx1:       .res 1
_ly1:       .res 1
ptr:        .res 2          ; framebuffer pointer (row/column byte, Y = y&7)
dptr:       .res 2          ; dirty map pointer
mask:       .res 1          ; current pixel bit
ddx:        .res 1
ddy:        .res 1
err:        .res 1
cnt:        .res 1
ydir:       .res 1          ; 0 = down the screen, $FF = up
_gfx_base:  .res 1          ; high byte of the buffer gfx_line draws into
bgptr:      .res 2          ; background pointer used by copycell

.segment "BSS"
_gfx_src:   .res 2          ; source pointer for gfx_vput8

.segment "RODATA"

bitmask:    .byte $80,$40,$20,$10,$08,$04,$02,$01

; Dirty map address for each framebuffer row page (row*32)
dlo_tab:
.repeat 24, R
            .byte <(DIRTY + R*32)
.endrepeat
dhi_tab:
.repeat 24, R
            .byte >(DIRTY + R*32)
.endrepeat

.segment "CODE"

; ---------------------------------------------------------------------------
; void gfx_init(void)
; Clear the framebuffer and mark every cell as "had content last frame" so
; the first blit wipes whatever is in VRAM.
; ---------------------------------------------------------------------------
_gfx_init:
            lda #FBHI
            sta _gfx_base
            lda #>FB
            jsr clr6k
            lda #>BG
            jsr clr6k

            lda #>DIRTY
            sta ptr+1
            ldx #3                  ; 3 pages = 768 cells
            lda #2
@dclr:      sta (ptr),y
            iny
            bne @dclr
            inc ptr+1
            dex
            bne @dclr
            rts

; clear the 6K buffer whose high byte is in A
clr6k:      sta ptr+1
            stz ptr
            ldx #24                 ; 24 pages
            lda #0
            tay
@lp:        sta (ptr),y
            iny
            bne @lp
            inc ptr+1
            dex
            bne @lp
            rts

; ---------------------------------------------------------------------------
; mark - flag the cell under ptr as drawn this frame. Preserves Y.
; ---------------------------------------------------------------------------
mark:
            ldx ptr+1
            cpx #FBHI               ; not the framebuffer (drawing background)
            bcc @skip
            lda ptr
            lsr a
            lsr a
            lsr a
            ora dlo_tab-FBHI,x
            sta dptr
            lda dhi_tab-FBHI,x
            sta dptr+1
            lda #1
            ora (dptr)
            sta (dptr)
@skip:      rts

; ---------------------------------------------------------------------------
; void __fastcall__ gfx_mark(unsigned int fboffset)
; Mark the cell containing framebuffer offset as drawn (for C code that pokes
; the framebuffer directly, e.g. text).
; ---------------------------------------------------------------------------
_gfx_mark:
            sta ptr
            txa
            clc
            adc #FBHI
            sta ptr+1
            jmp mark

; ---------------------------------------------------------------------------
; void gfx_line(void)
; Draw a line from (lx0,ly0) to (lx1,ly1). Coordinates must already be
; clipped to 0..255 / 0..191.
; ---------------------------------------------------------------------------
_gfx_line:
            ; always draw left to right
            lda _lx1
            cmp _lx0
            bcs @noswap
            ldx _lx0
            sta _lx0
            stx _lx1
            lda _ly0
            ldx _ly1
            sta _ly1
            stx _ly0
@noswap:
            sec
            lda _lx1
            sbc _lx0
            sta ddx

            sec
            lda _ly1
            sbc _ly0
            bcs @down
            eor #$ff                ; negate (carry is clear)
            adc #1
            sta ddy
            lda #$ff
            sta ydir
            bra @setup
@down:      sta ddy
            stz ydir

@setup:     lda _lx0
            and #$f8
            sta ptr
            lda _ly0
            lsr a
            lsr a
            lsr a
            clc
            adc _gfx_base
            sta ptr+1
            lda _lx0
            and #7
            tax
            lda bitmask,x
            sta mask
            jsr mark
            lda _ly0
            and #7
            tay

            lda ddx
            cmp ddy
            bcc ymajor

; --- X major: step x every pixel ---
xmajor:
            sta cnt                 ; A = ddx
            lsr a
            sta err
@plot:      lda (ptr),y
            ora mask
            sta (ptr),y
            lda cnt
            beq @done
            dec cnt
            lsr mask                ; step right
            bcc @err
            ror mask                ; carry set -> mask = $80
            lda ptr
            adc #8                  ; carry is clear after ror
            sta ptr
            jsr mark
@err:       lda err
            sec
            sbc ddy
            sta err
            bcs @plot
            adc ddx
            sta err
            bit ydir
            bmi @up
            iny
            cpy #8
            bne @plot
            ldy #0
            inc ptr+1
            jsr mark
            bra @plot
@up:        dey
            bpl @plot
            ldy #7
            dec ptr+1
            jsr mark
            bra @plot
@done:      rts

; --- Y major: step y every pixel ---
ymajor:
            lda ddy
            sta cnt
            lsr a
            sta err
@plot:      lda (ptr),y
            ora mask
            sta (ptr),y
            lda cnt
            beq @done
            dec cnt
            bit ydir
            bmi @up
            iny
            cpy #8
            bne @err
            ldy #0
            inc ptr+1
            jsr mark
            bra @err
@up:        dey
            bpl @err
            ldy #7
            dec ptr+1
            jsr mark
@err:       lda err
            sec
            sbc ddx
            sta err
            bcs @plot
            adc ddy
            sta err
            lsr mask                ; step right
            bcc @plot
            ror mask
            lda ptr
            adc #8                  ; carry is clear after ror
            sta ptr
            jsr mark
            bra @plot
@done:      rts

; ---------------------------------------------------------------------------
; void gfx_blit(void)
; Copy changed cells to the VDP pattern table and clear them in RAM.
; The VDP needs ~8us between VRAM accesses in Graphics II (~43 cycles at
; 5.35MHz), so each byte copy is padded out to at least that.
; ---------------------------------------------------------------------------
wait12:     rts                     ; jsr+rts = 12 cycles

_gfx_blit:
            lda #FBHI
            sta ptr+1
            lda #<DIRTY
            sta dptr
            lda #>DIRTY
            sta dptr+1
@row:       ldy #0
@scan:      lda (dptr),y            ; 14 cycles per clean cell
            bne @found
@cont:      iny
            cpy #32
            bne @scan
            lda dptr
            clc
            adc #32
            sta dptr
            bcc :+
            inc dptr+1
:           inc ptr+1
            lda ptr+1
            cmp #FBHI+24
            bne @row
            rts
@found:     and #1                  ; drawn this frame -> "old content" next frame
            asl a
            sta (dptr),y
            tya
            asl a
            asl a
            asl a
            sta ptr                 ; column * 8
            phy
            jsr copycell
            ply
            bra @cont

; copy the 8 bytes of the cell at ptr to VRAM and clear them in RAM
copycell:
            lda ptr
            sta bgptr
            lda ptr+1
            clc
            adc #<((>BG) - FBHI)   ; (wraps: BG is below FB)
            sta bgptr+1
            php
            sei
            lda ptr                 ; VRAM address = framebuffer offset
            sta VDP_CTRL
            lda ptr+1
            sec
            sbc #FBHI
            ora #$40                ; write mode
            sta VDP_CTRL
            ldy #0
.repeat 8
            lda (ptr),y             ; 5
            ora (bgptr),y           ; 5
            sta VDP_DATA            ; 4
            lda #0                  ; 2
            sta (ptr),y             ; 6
            iny                     ; 2
            jsr wait12              ; 12
            nop                     ; 2 x 4 = 8  -> 44 cycles per byte
            nop
            nop
            nop
.endrepeat
            plp
            rts

; ---------------------------------------------------------------------------
; void __fastcall__ gfx_vput8(unsigned int vaddr)
; Write the 8 bytes at gfx_src straight to VRAM (used for HUD text, which
; lives outside the framebuffer/dirty system).
; ---------------------------------------------------------------------------
_gfx_vput8:
            php
            sei
            sta VDP_CTRL
            txa
            ora #$40
            sta VDP_CTRL
            lda _gfx_src
            sta ptr
            lda _gfx_src+1
            sta ptr+1
            ldy #0
@lp:        lda (ptr),y             ; 5
            sta VDP_DATA            ; 4
            jsr wait12              ; 12
            jsr wait12              ; 12
            nop                     ; 2
            nop                     ; 2
            iny                     ; 2
            cpy #8                  ; 2
            bne @lp                 ; 3  -> 44 cycles per byte
            plp
            rts
