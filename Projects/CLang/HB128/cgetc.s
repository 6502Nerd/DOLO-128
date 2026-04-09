


.export  _cgetc, _getch

.segment  "CODE"

_cgetc:
_getch:
    ;lda #97
    ;jsr $c001
    sec
    jsr $c004
    ldx #$00
    rts
