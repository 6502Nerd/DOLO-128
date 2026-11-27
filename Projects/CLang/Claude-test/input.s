; ---------------------------------------------------------------------------
; input.s - joystick reading in the VDP (vertical blank) interrupt
;
; The game loop only runs every few frames, so a quick tap of the fire button
; can fall between two reads. Instead the joystick is read every vblank here:
;   joy_now   - current joystick bits (1 = pressed, J_* masks in tank.c)
;   joy_fire  - set to non-zero when fire goes from released to pressed;
;               the game clears it when it has dealt with it
;
; void input_init(void) installs the handler (via dfcl_vbint).
; While it is installed, nothing else should talk to the AY chip outside the
; interrupt, because the joystick port is read through the AY. Sound effects
; are therefore also driven from here (sound.s).
; ---------------------------------------------------------------------------

.include "../HB128/hb128.inc"

.export _input_init, _joy_now, _joy_fire
.import _dfcl_vbint, snd_update

.segment "BSS"
_joy_now:   .res 1
_joy_fire:  .res 1
joy_prev:   .res 1

.segment "CODE"

_input_init:
            stz _joy_now
            stz _joy_fire
            stz joy_prev
            lda #<vb_input
            ldx #>vb_input
            jmp _dfcl_vbint

; Called from the ROM IRQ handler on every vblank (registers already saved)
vb_input:
            jsr _dfcl0_snd_get_joy0     ; Y = joystick, active low (same in every ROM bank)
            tya
            eor #$ff
            sta _joy_now
            lda joy_prev                ; rising edge of fire?
            eor #$ff
            and _joy_now
            and #$80
            beq :+
            sta _joy_fire
:           lda _joy_now
            sta joy_prev
            jmp snd_update              ; sound effects (sound.s)
