	
;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  IRQ.S
;*	This is the IRQ handler - handles both the vertical
;*  blank interrupt from the VDP as well as software break.
;*  
;*  As the handler has to be in every bank and it also
;*  accesses the VDP, then low level VDP routines are also
;*  bundled in this file to ensure they are always available
;*  without a bank switch being needed (which is quite slow)
;**********************************************************

;* NMI handler installs to handle serial receive data register full
init_nmi
	; Core IRQ handler
	lda #lo(nmi)
	sta int_nmi
	lda #hi(nmi)
	sta int_nmi+1

	lda #lo(null_handler)
	sta int_usercia1
	lda #hi(null_handler)
	sta int_usercia1+1

	rts

;* Calls the master IRQ handler
call_nmi_master
;	jmp (int_nmi)

;* Master NMI handler
;* 6551 uses this - fills the receive buffer
;* VIA 2 uses this- user interrupt
nmi
	pha

	lda SER_STATUS				; Read status register (clears int bit)
	bpl	nmi_skip_acia			; If no interrupt don't do anything

	phy
	lda SER_DATA				; Read the data register of 6551
	ldy ser_last				; Put byte in last position of FIFO
	sta ser_buf,y
	inc ser_last				; Advance position of last

	ply
nmi_skip_acia
nmi_fin
	pla
	rti


;* Obviously this can only be done with
;* interrupts disabled!
init_irq
	; Core IRQ handler
	lda #lo(irq)
	sta int_irq
	lda #hi(irq)
	sta int_irq+1
	
	; Core BRK handler
	lda #lo(irq_brk)
	sta int_brk
	lda #hi(irq_brk)
	sta int_brk+1

	; User handlers for VDP, PIA0 interrupts
	lda #lo(null_handler)
	sta int_uservdp
	lda #hi(null_handler)
	sta int_uservdp+1

	lda #lo(null_handler)
	sta int_usercia0
	lda #hi(null_handler)
	sta int_usercia0+1

	rts

;* Calls the master IRQ handler
call_irq_master
	jmp (int_irq)
	
;* Calls the BRK handler
call_irq_brk
	jmp (int_brk)

;* Call the userVDP handler
call_irq_uservdp
	jmp (int_uservdp)
	
;* Call the user CIA0 handler
call_irq_usercia0
	jmp (int_usercia0)

;* Call the user CIA1 handler
call_irq_usercia1
	jmp (int_usercia1)
	
;* null interrupt
null_irq
	rti

;* null handler
null_handler
	rts
	

;* Master IRQ handler
irq
	_pushAXY

	; Check if IRQ or BRK
	; load P from stack in to A
	tsx
	lda 0x104,x
	; BRK bit set?
	and #0x10
	bne call_irq_brk
	
	clc						; Standard behaviour

	;* Try PIA1 first for rapid Timer handling
	lda IO_1 + IFR
	bpl irq_check_vdp		; Skip if no interrupt
	; Reset interrupt by reading T1C-L
	lda IO_1+T1CL
	phy
	phx
	; Swtich to RAM bank 2 don't touch anything else
	lda IO_0+PRB
	pha                     ; Remember the bank #
	and #0b11001111
	ora #0b00100000
	sta IO_0+PRB
	; Switch out ROM for RAM
	lda IO_1+PRB                    ; Get current ROM / PRB state
	pha
	and #(0xff ^ MM_DIS)            ; Switch off ROM bit
	sta IO_1+PRB                    ; Update port to activate setting
	inc pt3_int 				  	; Set PT3 interrupt flag
	jsr call_irq_usercia1			; Call user cia1 handler
	; Restore ROM
	pla                             ; Get original port setting
	sta IO_1+PRB                    ; Update port to activate setting
	; Restore RAM bank
	pla                             ; Get original port setting
	sta IO_0+PRB                    ; Update port to activate setting
	plx
	ply

	;* Try VDP next
irq_check_vdp	
	lda VDP_STATUS			; Read status register
	bpl	irq_check_cia0		; Skip if not VBLANK
	jsr call_irq_uservdp	; Call use VDP handler
	jsr int_vdp_handler		; Call  OS VDP handler
	jsr int_kb_handler		; Call OS cia0 handler (keyboard)

	;* Try VIA0 last as it's keyboard (low speed)
irq_check_cia0
	lda IO_0 + IFR
	bpl irq_fin
	jsr call_irq_usercia0	; Call user cia0 handler

irq_fin
	_pullAXY
	rti
	
;* Handle BRK
irq_brk
	; Handle BRK
	; Get PCL,H minus 2 gives the BRK instruction address
	sec
	lda 0x0105,x
	sbc #2
	sta df_brkpc
	lda 0x0106,x
	sbc #0
	sta df_brkpc+1
	; Get the byte pointed to by old PC
	; which is 1 on from the BRK
	ldy #1
	lda (df_brkpc),y
	sta df_brkval
	sta errno
	; now update the return address
	lda df_pc
	sta 0x105,x
	lda df_pc+1
	sta 0x106,x
	
	_pullAXY
	; Save the registers in temp area
	sta num_a
	stx num_a+1
	sty num_a+2
	; when RTI occurs:
	;  will return to error handler
	;  df_brkval will contain signature
	rti
	
;****************************************
;* int_kb_handler
;* Keyboard interrupt handler
;****************************************
int_kb_handler	
	lda kb_deb				; If keyboard pressed is debounce 0?
	bne int_skip_scan		; If not zero, then don't check keys
	lda IO_0 + IFR			; Check status register CIA0
	and #IFR_CA2			; Keyboard pressed?
	beq int_keys_up
int_do_read
	sta kb_pressed			; Put non-zero in to this flag
	lda kb_debounce			; Set debounce
	sta kb_deb
int_skip_scan
	lda #IFR_CA2			; Clear CA2
	sta IO_0 + IFR
	rts
int_keys_up					; No key pressed
	stz kb_raw				; Using 65c02 stz opcode
	stz kb_last
	stz kb_code
	stz kb_deb
	stz kb_rep
	rts
	
;****************************************
;* int_vdp_handler
;* VDP interrupt handler
;****************************************
int_vdp_handler
	jsr update_timers	; If it is then update system timers (kernel routine)

	lda vdp_curoff		; Is cursor enabled?
	bne int_vdp_fin		; Skip if not

	dec vdp_curstat		; Decrement VDP counter
	lda vdp_curstat		; Check it
	and #0x7f			; If bottom 7 bits !=0
	bne int_vdp_fin		; No flashing to be done
	lda vdp_curstat		; Invert top bit (bottoms bits==0)
	eor #0x80+VDP_FLASH	; Start counter again
	sta vdp_curstat		

	clc					; Add offset for cursor address in vram
	lda gr_scrngeom+gr_cur_ptr
	adc gr_scrngeom+gr_cur_off
	tax
	lda gr_scrngeom+gr_cur_ptr+1
	adc #0

	jsr vdp_wr_addr
	
	lda vdp_curstat
	and #0x80
	eor vdp_curval		; EOR top bit with what is under the cursor
	jsr vdp_wr_vram
int_vdp_fin	
	rts


;****************************************
;* update_timers
;* Update 24 bit timer and debounce counters
;****************************************
update_timers
	inc vdp_int_cnt
	bne inc_kb_timers
	inc vdp_int_cnt+1
inc_kb_timers
	ldx kb_deb			; Is debounce 0?
	beq skip_kb_deb
	dec kb_deb
skip_kb_deb
	ldx kb_rep			; Is repeat timer 0?
	beq skip_kb_rep
	dec kb_rep
skip_kb_rep
	rts
	
