.include "../hb128/hb128.inc"

ZAPVOL=10
FOEVOL=8
FOEUPPER=220
FOELOWER=100

.export _do_sound

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import _zap_snd,_foe_snd


.segment "BSS"
snd_hi:
    .res 1
foe_freq:
    .res 1
foe_dir:
    .res 1
.segment  "CODE"

_do_sound:
    ; Zap sound
    lda _zap_snd
    beq skip_zap
    clc
    adc #15
    sta _zap_snd
    cmp #(255-16)
    bcs clear_zap
    stz snd_hi
    asl a
    rol snd_hi
    asl a
    rol snd_hi
    tay                         ; Low byte of frequency
    ldx #0                      ; Channel A fine tune
    jsr _dfcl0_snd_set           ; Set reg X to value Y
    lda snd_hi
    tay                         ; High byte of frequency
    ldx #1                      ; Channel A coarse tune
    jsr _dfcl0_snd_set           ; Set reg X to value Y
    lda #ZAPVOL                 ; Make sure volume on
    bra skip_zap                 ; skip zero vol
clear_zap:
    lda #0
    sta _zap_snd
skip_zap:
    tay                         ; Y is the value
    ldx #8                      ; ChanA volume register
    jsr _dfcl0_snd_set           ; Set reg X to value Y

    ; Foe siren
    lda _foe_snd
    beq skip_foe
    lda foe_dir                 ; Alarm sound up/down?
    bmi foe_down
    clc
    lda foe_freq
    adc _foe_snd
    sta foe_freq
    tay
    ldx #2                      ; Chan B fine tune
    jsr _dfcl0_snd_set           ; Set reg X to value Y
    cmp #FOEUPPER               ; > upper?
    ldy #FOEVOL
    bcs dir_change
    bcc fin_foe
foe_down:
    sec
    lda foe_freq
    sbc _foe_snd
    sta foe_freq
    tay
    ldx #2                      ; Chan B fine tune
    jsr _dfcl0_snd_set           ; Set reg X to value Y
    cmp #FOELOWER               ; < upper?
    ldy #FOEVOL
    bcs fin_foe
dir_change:
    lda foe_dir
    eor #128
    sta foe_dir
    bra fin_foe
skip_foe:
    ldy #0                         ; Y is the value
fin_foe:
    ldx #9                      ; ChanB volume register
    jsr _dfcl0_snd_set           ; Set reg X to value Y

    rts