; ---------------------------------------------------------------------------
; sound.s - AY-3-8910 sound effects, run from the vblank interrupt
;
; The joystick is read through the AY's IO port B, so to keep the two from
; colliding ALL AY access happens in the interrupt (see input.s). The game
; only sets these flags/values:
;
;   sfx_pshot = 1   player fires          (channel B: sharp falling "pew")
;   sfx_eshot = 1   enemy fires           (channel B: lower, longer)
;   sfx_eboom = 1   enemy tank destroyed  (channel C: noise burst)
;   sfx_pboom = 1   player hit            (channel C: long deep rumble)
;   sfx_ping  = 1   enemy appears on radar (channel C: high fading tone,
;                   unless an explosion is using the channel)
;   engine    = 0 off, 1 idle, 2 moving   (channel A: low rough hum)
;
; snd_update is called once per vblank and writes the AY registers.
; AY clock is 1.34MHz: tone frequency = 83750 / period.
; ---------------------------------------------------------------------------

.include "../HB128/hb128.inc"

.export _sfx_pshot, _sfx_eshot, _sfx_eboom, _sfx_pboom, _sfx_ping, _engine
.export snd_update

SND_SET = _dfcl0_snd_set            ; X = register, Y = value (in every ROM bank)

PING_PER = 64                       ; radar ping: ~1300Hz
PING_LEN = 28                       ;   ticks
PING_DEC = 8                        ;   fade per tick (4.4)

.segment "BSS"
_sfx_pshot: .res 1
_sfx_eshot: .res 1
_sfx_eboom: .res 1
_sfx_pboom: .res 1
_sfx_ping:  .res 1
_engine:    .res 1

btime:      .res 1                  ; channel B (shots): ticks left
bper:       .res 2                  ;   tone period
bstep:      .res 1                  ;   period increase per tick (pitch falls)
bvol:       .res 1                  ;   volume, 4.4 fixed point
bdec:       .res 1                  ;   volume decrease per tick (4.4)
bnoise:     .res 1                  ;   ticks of noise mixed in

ctime:      .res 1                  ; channel C (explosions): ticks left
cvol:       .res 1                  ;   volume, 4.4 fixed point
cdec:       .res 1                  ;   volume decrease per tick (4.4)
cnp:        .res 1                  ;   noise period (bigger = deeper)
cnstep:     .res 1                  ;   ticks between noise period increases
cncnt:      .res 1

ptime:      .res 1                  ; radar ping (channel C tone): ticks left
pvol:       .res 1                  ;   volume, 4.4 fixed point

jit:        .res 1                  ; engine pitch jitter
mix:        .res 1                  ; mixer register being built

.segment "RODATA"
; shot effects: 0 = player, 1 = enemy
fxb_plo:    .byte <90,  <240
fxb_phi:    .byte >90,  >240
fxb_step:   .byte 20,   34
fxb_len:    .byte 14,   18
fxb_vol:    .byte 15*16, 13*16
fxb_dec:    .byte 17,   11
fxb_noise:  .byte 4,    6
; explosions: 0 = enemy destroyed, 1 = player hit
fxc_len:    .byte 50,   120
fxc_vol:    .byte 15*16, 15*16
fxc_dec:    .byte 5,    2
fxc_np:     .byte 12,   22
fxc_nstep:  .byte 6,    12

.segment "CODE"

start_b:    lda fxb_plo,x
            sta bper
            lda fxb_phi,x
            sta bper+1
            lda fxb_step,x
            sta bstep
            lda fxb_len,x
            sta btime
            lda fxb_vol,x
            sta bvol
            lda fxb_dec,x
            sta bdec
            lda fxb_noise,x
            sta bnoise
            rts

start_c:    lda fxc_len,x
            sta ctime
            lda fxc_vol,x
            sta cvol
            lda fxc_dec,x
            sta cdec
            lda fxc_np,x
            sta cnp
            lda fxc_nstep,x
            sta cnstep
            sta cncnt
            rts

; ---------------------------------------------------------------------------
snd_update:
            ; --- new effects requested by the game ---
            lda _sfx_pshot
            beq :+
            stz _sfx_pshot
            ldx #0
            jsr start_b
:           lda _sfx_eshot
            beq :+
            stz _sfx_eshot
            ldx #1
            jsr start_b
:           lda _sfx_eboom
            beq :+
            stz _sfx_eboom
            ldx #0
            jsr start_c
:           lda _sfx_pboom
            beq :+
            stz _sfx_pboom
            ldx #1
            jsr start_c
:           lda _sfx_ping
            beq :+
            stz _sfx_ping
            lda #PING_LEN
            sta ptime
            lda #14*16
            sta pvol
:
            lda #%00111111              ; all off; IO ports A and B stay inputs
            sta mix

            ; --- channel A: engine ---
            lda _engine
            bne @eng
            ldx #8
            ldy #0
            jsr SND_SET
            bra @engdone
@eng:       lda jit                     ; rough rumble: wobble the period
            clc
            adc #37
            sta jit
            and #63
            ldy _engine
            cpy #2
            beq @move
            clc
            adc #<2400                  ; idle ~35Hz
            tay
            lda #>2400
            adc #0
            ldx #5                      ; volume
            bra @engset
@move:      clc
            adc #<1500                  ; moving ~55Hz
            tay
            lda #>1500
            adc #0
            ldx #7
@engset:    phx
            pha
            ldx #0
            jsr SND_SET                 ; R0 = period low (Y)
            ply
            ldx #1
            jsr SND_SET                 ; R1 = period high
            ply
            ldx #8
            jsr SND_SET                 ; R8 = volume
            lda mix
            and #%11111110              ; tone A on
            sta mix
@engdone:
            ; --- channel B: shots ---
            lda btime
            beq @boff
            dec btime
            ldx #2
            ldy bper
            jsr SND_SET
            ldx #3
            ldy bper+1
            jsr SND_SET
            lda bvol
            lsr a
            lsr a
            lsr a
            lsr a
            tay
            ldx #9
            jsr SND_SET
            lda mix
            and #%11111101              ; tone B on
            ldx bnoise
            beq :+
            and #%11101111              ; noise B on
            dec bnoise
:           sta mix
            clc                         ; pitch falls
            lda bper
            adc bstep
            sta bper
            bcc :+
            inc bper+1
:           sec                         ; fade
            lda bvol
            sbc bdec
            bcs :+
            lda #0
:           sta bvol
            bra @bdone
@boff:      ldx #9
            ldy #0
            jsr SND_SET
@bdone:
            ; --- channel C: explosions ---
            lda ctime
            beq @coff
            dec ctime
            lda cvol
            lsr a
            lsr a
            lsr a
            lsr a
            tay
            ldx #10
            jsr SND_SET
            lda mix
            and #%11011111              ; noise C on
            sta mix
            sec                         ; fade
            lda cvol
            sbc cdec
            bcs :+
            lda #0
:           sta cvol
            dec cncnt                   ; rumble gets deeper as it fades
            bne :+
            lda cnstep
            sta cncnt
            lda cnp
            cmp #31
            bcs :+
            inc cnp
:           ldy cnp
            bra @noise
@coff:      lda ptime                   ; no explosion: radar ping?
            beq @poff
            dec ptime
            ldx #4
            ldy #<PING_PER
            jsr SND_SET
            ldx #5
            ldy #>PING_PER
            jsr SND_SET
            lda pvol
            lsr a
            lsr a
            lsr a
            lsr a
            tay
            ldx #10
            jsr SND_SET
            lda mix
            and #%11111011              ; tone C on
            sta mix
            sec                         ; fade
            lda pvol
            sbc #PING_DEC
            bcs :+
            lda #0
:           sta pvol
            ldy #6                      ; noise period for shots
            bra @noise
@poff:      ldx #10
            ldy #0
            jsr SND_SET
            ldy #6                      ; noise period for shots
@noise:     ldx #6
            jsr SND_SET
            ; --- mixer ---
            ldx #7
            ldy mix
            jmp SND_SET
