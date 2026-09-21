.include "../hb128/hb128.inc"

.export _vb_handler

.import _ay;
.import _ay_handler;

.segment  "CODE"

_vb_handler:
    lda _dfcl0_pt3_amplA
    sta _ay;
    lda _dfcl0_pt3_amplB
    sta _ay+1;
    lda _dfcl0_pt3_amplC
    sta _ay+2;
    jsr _ay_handler;
    rts
