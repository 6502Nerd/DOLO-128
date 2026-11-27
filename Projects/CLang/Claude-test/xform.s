; ---------------------------------------------------------------------------
; xform.s - camera transform, per-vertex projection and edge drawing
;
; unsigned char to_camera(void)
;   Object at world (tc_x, tc_z). Using the player position (px, pz) and
;   heading sin/cos (ps, pc), computes its camera space centre:
;       dx, dz = wrapped world offsets (world is 8192 units square)
;       ccz = dx*ps/128 + dz*pc/128      (distance ahead)
;       ccx = dx*pc/128 - dz*ps/128      (distance to the right)
;   Returns 0 (and leaves ccx/ccz alone) if |dx| or |dz| > FARZ.
;
; void xform_model(void)
;   Inputs: xf_model (Model*), xf_ccx, xf_ccz (object centre in camera
;   space), xf_sa, xf_ca (sin/cos of object angle relative to camera).
;   For each vertex v:
;       x = ccx + v.x*ca/128 + v.z*sa/128
;       z = ccz - v.x*sa/128 + v.z*ca/128
;       y = v.y - CAMH
;   Stores vx/vy/vz, and when z >= NEARZ also sx = 128 + x*256/z,
;   sy = HORIZON - y*256/z and vfront = 1 (else vfront = 0).
;
; void draw_edges(void)
;   Draws every edge of xf_model. Edges fully on screen go straight to
;   gfx_line; anything needing clipping is handed to C edge_slow(a, b).
; ---------------------------------------------------------------------------

.export _to_camera, _xform_model, _draw_edges
.export _tc_x, _tc_z
.export _xf_model, _xf_ccx, _xf_ccz, _xf_sa, _xf_ca
.import _px, _pz, _ps, _pc, _ccx, _ccz
.import _vx, _vy, _vz, _sx, _sy, _vfront, _clipy
.import _gfx_line, _edge_slow
.import smul16, div16, mul7
.importzp d_x, d_z
.import pusha
.importzp _lx0, _ly0, _lx1, _ly1

CAMH    = 24
NEARZ   = 16
HORIZON = 104
FARZ    = 3000

.segment "ZEROPAGE"
vptr:       .res 2          ; vertex / edge list pointer

.segment "BSS"
_tc_x:      .res 2
_tc_z:      .res 2
_xf_model:  .res 2
_xf_ccx:    .res 2
_xf_ccz:    .res 2
_xf_sa:     .res 1
_xf_ca:     .res 1
dx:         .res 2
dz:         .res 2
acc:        .res 2
cnt:        .res 1
vidx:       .res 1          ; vertex index * 2
vx8:        .res 1          ; current vertex x, y, z (signed bytes)
vy8:        .res 1
vz8:        .res 1
tx:         .res 2          ; transformed x, z
tz:         .res 2
tmp:        .res 1
ea:         .res 1          ; edge end vertex indices
eb:         .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
_to_camera:
            ; dx = (tc_x - px) as a signed 13 bit value
            sec
            lda _tc_x
            sbc _px
            sta dx
            lda _tc_x+1
            sbc _px+1
            and #$1f
            cmp #$10
            bcc :+
            ora #$e0
:           sta dx+1
            ; reject if |dx| > FARZ:  (dx + FARZ) >= 2*FARZ+1 unsigned
            clc
            lda dx
            adc #<FARZ
            tay
            lda dx+1
            adc #>FARZ
            cpy #<(2*FARZ+1)
            sbc #>(2*FARZ+1)
            bcc :+
            jmp @far
:
            sec
            lda _tc_z
            sbc _pz
            sta dz
            lda _tc_z+1
            sbc _pz+1
            and #$1f
            cmp #$10
            bcc :+
            ora #$e0
:           sta dz+1
            clc
            lda dz
            adc #<FARZ
            tay
            lda dz+1
            adc #>FARZ
            cpy #<(2*FARZ+1)
            sbc #>(2*FARZ+1)
            bcs @far

            ; ccz = dx*ps + dz*pc
            lda dx
            ldx dx+1
            ldy _ps
            jsr smul16
            sta acc
            stx acc+1
            lda dz
            ldx dz+1
            ldy _pc
            jsr smul16
            clc
            adc acc
            sta _ccz
            txa
            adc acc+1
            sta _ccz+1
            ; ccx = dx*pc - dz*ps
            lda dz
            ldx dz+1
            ldy _ps
            jsr smul16
            sta acc
            stx acc+1
            lda dx
            ldx dx+1
            ldy _pc
            jsr smul16
            sec
            sbc acc
            sta _ccx
            txa
            sbc acc+1
            sta _ccx+1
            lda #1
            ldx #0
            rts
@far:       lda #0
            tax
            rts

; ---------------------------------------------------------------------------
_xform_model:
            lda _xf_model
            sta vptr
            lda _xf_model+1
            sta vptr+1
            lda (vptr)              ; nv
            sta cnt
            ldy #2
            lda (vptr),y            ; v pointer
            tax
            iny
            lda (vptr),y
            sta vptr+1
            stx vptr
            stz vidx
            lda cnt
            bne @vert
            rts

@vert:      ldy #0
            lda (vptr),y
            sta vx8
            iny
            lda (vptr),y
            sta vy8
            iny
            lda (vptr),y
            sta vz8
            lda vptr                ; advance to next vertex
            clc
            adc #3
            sta vptr
            bcc :+
            inc vptr+1
:
            ; tx = ccx + x*ca + z*sa
            lda vx8
            ldx _xf_ca
            jsr mul7
            clc
            adc _xf_ccx
            sta tx
            txa
            adc _xf_ccx+1
            sta tx+1
            lda vz8
            ldx _xf_sa
            jsr mul7
            clc
            adc tx
            sta tx
            txa
            adc tx+1
            sta tx+1
            ; tz = ccz - x*sa + z*ca
            lda vz8
            ldx _xf_ca
            jsr mul7
            clc
            adc _xf_ccz
            sta tz
            txa
            adc _xf_ccz+1
            sta tz+1
            lda vx8
            ldx _xf_sa
            jsr mul7
            sta tmp
            lda tz
            sec
            sbc tmp
            sta tz
            stx tmp
            lda tz+1
            sbc tmp
            sta tz+1

            ; store camera space coordinates
            ldy vidx
            lda tx
            sta _vx,y
            lda tx+1
            sta _vx+1,y
            lda tz
            sta _vz,y
            lda tz+1
            sta _vz+1,y
            lda vy8
            sec
            sbc #CAMH
            sta _vy,y
            lda #0
            sbc #0                  ; vy8 is 0..127 so this sign-extends correctly
            sta _vy+1,y

            ; in front of the near plane?
            tya
            lsr a
            tax
            lda tz+1
            bmi @behind
            bne @front
            lda tz
            cmp #NEARZ
            bcs @front
@behind:    stz _vfront,x
            jmp @nextv

@front:     lda #1
            sta _vfront,x
            ; sx = 128 + x*256/z
            lda tx
            sta d_x
            lda tx+1
            sta d_x+1
            lda tz
            sta d_z
            lda tz+1
            sta d_z+1
            jsr div16
            ldy vidx
            clc
            adc #128
            sta _sx,y
            txa
            adc #0
            sta _sx+1,y
            ; sy = HORIZON - y*256/z   (d_z is unchanged by div16)
            lda _vy,y
            sta d_x
            lda _vy+1,y
            sta d_x+1
            jsr div16
            ldy vidx
            sta tmp
            lda #HORIZON
            sec
            sbc tmp
            sta _sy,y
            stx tmp
            lda #0
            sbc tmp
            sta _sy+1,y

@nextv:     inc vidx
            inc vidx
            dec cnt
            beq :+
            jmp @vert
:           rts

; ---------------------------------------------------------------------------
_draw_edges:
            lda _xf_model
            sta vptr
            lda _xf_model+1
            sta vptr+1
            ldy #1
            lda (vptr),y            ; ne
            sta cnt
            ldy #4
            lda (vptr),y            ; e pointer
            tax
            iny
            lda (vptr),y
            sta vptr+1
            stx vptr
            lda cnt
            bne @edge
            rts

@edge:      lda (vptr)
            sta ea
            ldy #1
            lda (vptr),y
            sta eb
            lda vptr
            clc
            adc #2
            sta vptr
            bcc :+
            inc vptr+1
:
            ldx ea
            lda _vfront,x
            ldx eb
            and _vfront,x
            beq @slow               ; one or both ends behind the near plane

            ; fast path: both ends on screen?
            lda ea
            asl a
            tay
            lda _sx+1,y
            bne @slow
            lda _sy+1,y
            bne @slow
            lda _sy,y
            cmp _clipy
            bcc @slow
            cmp #192
            bcs @slow
            sta _ly0
            lda _sx,y
            sta _lx0
            lda eb
            asl a
            tay
            lda _sx+1,y
            bne @slow
            lda _sy+1,y
            bne @slow
            lda _sy,y
            cmp _clipy
            bcc @slow
            cmp #192
            bcs @slow
            sta _ly1
            lda _sx,y
            sta _lx1
            jsr _gfx_line
            bra @nexte

@slow:      ldx ea                  ; nothing to draw if both are behind
            lda _vfront,x
            ldx eb
            ora _vfront,x
            beq @nexte
            lda ea
            jsr pusha
            lda eb
            jsr _edge_slow          ; void __fastcall__ edge_slow(a, b)

@nexte:     dec cnt
            beq :+
            jmp @edge
:           rts
