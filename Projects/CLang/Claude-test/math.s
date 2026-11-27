; ---------------------------------------------------------------------------
; math.s - fast fixed point helpers for the 3D pipeline
;
; C callable:
;   int __fastcall__ smul(int a, signed char s);   returns (a * s) / 128
;   int __fastcall__ pdiv(int a, int z);           returns (a * 256) / z, z > 0
;                                                  saturated to +/-16383
; Assembly entry points (no C stack):
;   smul16  A/X = a, Y = s          -> A/X = (a*s)/128
;   div16   d_x = a, d_z = z        -> A/X = (a*256)/z
;   mul7    A = a, X = s (bytes)    -> A/X = (a*s)/128
;   negax   A/X = -A/X
;
; Multiplies use quarter squares: a*b = sq(a+b) - sq(|a-b|), sq(n) = n*n/4
; ---------------------------------------------------------------------------

.export _smul, _pdiv, smul16, div16, mul7, negax
.exportzp d_x, d_z
.import popax, _sq_lo, _sq_hi

.segment "ZEROPAGE"
d_x:        .res 2          ; divide numerator (signed)
d_z:        .res 2          ; divide denominator (> 0)
d_r:        .res 2          ; remainder
d_q:        .res 2          ; quotient
d_d:        .res 1          ; remaining dividend bits
d_sg:       .res 1          ; sign of result (bit 7)

.segment "BSS"
m_a:        .res 2
m_s:        .res 1
m_t:        .res 1
m_b:        .res 1
m_p:        .res 2          ; mulu8 product
m_q:        .res 3          ; smul16 24-bit product
m_sign:     .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
; negax: A/X = -A/X
negax:      eor #$ff
            clc
            adc #1
            pha
            txa
            eor #$ff
            adc #0
            tax
            pla
            rts

; ---------------------------------------------------------------------------
; mulu8: A * Y (unsigned bytes) -> m_p (16 bit)
mulu8:
            sty m_b
            sta m_t
            sec
            sbc m_b
            bcs :+
            eor #$ff                ; carry clear: ~x + 1 = -x
            adc #1
:           tay                     ; Y = |a-b|
            lda m_t
            clc
            adc m_b
            tax                     ; X = a+b (low 8 bits)
            bcs @hi
            sec
            lda _sq_lo,x
            sbc _sq_lo,y
            sta m_p
            lda _sq_hi,x
            sbc _sq_hi,y
            sta m_p+1
            rts
@hi:        sec
            lda _sq_lo+256,x
            sbc _sq_lo,y
            sta m_p
            lda _sq_hi+256,x
            sbc _sq_hi,y
            sta m_p+1
            rts

; ---------------------------------------------------------------------------
; smul16: A/X = a (signed), Y = s (signed) -> A/X = (a*s)/128
smul16:
            sty m_sign
            cpy #$80
            bcc :+
            pha
            tya
            eor #$ff
            inc a
            tay
            pla
:           sty m_s
            cpx #$80
            bcc @apos
            pha
            txa
            eor m_sign
            sta m_sign              ; result sign = sign(a) ^ sign(s)
            pla
            jsr negax
@apos:      stx m_a+1
            ldy m_s
            jsr mulu8               ; a_lo * s
            lda m_p
            sta m_q
            lda m_p+1
            sta m_q+1
            lda m_a+1
            ldy m_s
            jsr mulu8               ; a_hi * s
            clc
            lda m_q+1
            adc m_p
            sta m_q+1
            lda m_p+1
            adc #0
            sta m_q+2
            asl m_q                 ; >> 7
            rol m_q+1
            rol m_q+2
            lda m_q+1
            ldx m_q+2
            bit m_sign
            bpl :+
            jmp negax
:           rts

; int __fastcall__ smul(int a, signed char s)
_smul:
            sta m_t
            jsr popax
            ldy m_t
            jmp smul16

; ---------------------------------------------------------------------------
; mul7: A = a, X = s (signed bytes, |a|+|s| <= 255) -> A/X = (a*s)/128
mul7:
            sta m_sign
            cmp #$80
            bcc :+
            eor #$ff
            inc a
:           sta m_t                 ; |a|
            txa
            eor m_sign
            sta m_sign              ; sign of result in bit 7
            txa
            bpl :+
            eor #$ff
            inc a
:           tay                     ; Y = |s|
            clc
            adc m_t
            tax                     ; X = |a|+|s|
            tya
            sec
            sbc m_t
            bcs :+
            eor #$ff                ; |s-a|
            adc #1
:           tay
            sec
            lda _sq_lo,x
            sbc _sq_lo,y
            sta m_t
            lda _sq_hi,x
            sbc _sq_hi,y
            asl m_t                 ; >> 7
            rol a
            ldx #0
            bit m_sign
            bpl :+
            eor #$ff
            inc a
            beq :+                  ; -0 = 0
            dex                     ; X = $FF
:           rts

; ---------------------------------------------------------------------------
; div16: A/X = d_x*256/d_z (d_z > 0), saturated to +/-16383
div16:
            lda d_x+1
            sta d_sg
            bpl @pos
            lda #0
            sec
            sbc d_x
            sta d_x
            lda #0
            sbc d_x+1
            sta d_x+1
@pos:
            ; remainder starts as |x| >> 6, which must be < z or the
            ; quotient would exceed 16383
            lda d_x+1
            sta d_r+1
            lda d_x
            sta d_r
            ldx #6
:           lsr d_r+1
            ror d_r
            dex
            bne :-
            lda d_r
            cmp d_z
            lda d_r+1
            sbc d_z+1
            bcs @sat
            ; remaining 14 dividend bits: (|x| & 63) then 8 zero bits
            lda d_x
            asl a
            asl a
            sta d_d
            stz d_q
            stz d_q+1
            ldx #14
@lp:        asl d_d
            rol d_r
            rol d_r+1
            lda d_r
            sec
            sbc d_z
            tay
            lda d_r+1
            sbc d_z+1
            bcc @no
            sta d_r+1
            sty d_r
@no:        rol d_q                 ; carry = quotient bit
            rol d_q+1
            dex
            bne @lp
            lda d_q
            ldx d_q+1
            bra @sign
@sat:       lda #$ff
            ldx #$3f
@sign:      bit d_sg
            bpl :+
            jmp negax
:           rts

; int __fastcall__ pdiv(int a, int z)
_pdiv:
            sta d_z
            stx d_z+1
            jsr popax
            sta d_x
            stx d_x+1
            jmp div16
