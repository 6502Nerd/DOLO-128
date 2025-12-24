


.export  _hbputc, _cputc
.export  _hbgetc, _cgetc

.segment  "CODE"

_hbputc:
_cputc:
_putchar:
    jmp $c001

_hbgetc:
_cgetc:
_getch:
    sec
    jsr $c003
    ldx #$00
    rts
