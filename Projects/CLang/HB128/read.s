.constructor    initstdin
.export	  		_read

.import         popax, popptr1
.importzp       ptr1, ptr2, ptr3



.proc   _read

        sta     ptr3
        stx     ptr3+1          ; save count as result

        inx
        stx     ptr2+1
        tax
        inx
        stx     ptr2            ; save count with each byte incremented separately

        jsr     popptr1         ; get buf
        jsr     popax           ; get fd and discard

		ldy 	ptr3			; Get max count
		ldx     ptr1			; Get buffer pointer
		lda    	ptr1+1
		sec						; Echo on
		jsr  	$c5cf
		tya						; Get bytes read into A
		ldx    #0
		rts
.endproc

.segment  "ONCE"
initstdin:
    rts

