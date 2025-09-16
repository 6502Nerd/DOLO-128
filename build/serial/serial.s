;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  SERIAL.S
;*  Serial input/output handler - driving a 6551 ACIA.
;*  To handle WDC65c51 bug on transmit, use a delay
;*  to ensure byte is transmitted before the next byte.
;*
;**********************************************************

	; ROM code
	code


;****************************************
;* ser_get_byte
;* Get a byte (wait forever or just check)
;* Input : C = 1 for synchronous, 0 for async
;* Output : A = Byte code, C = 1 means A is invalid
;* Regs affected : P, A
;****************************************
ser_get_byte
	lda ser_first			; if first==last then buffer empty
	eor ser_last
	bne ser_got_byte
	bcs ser_get_byte
	sec
	rts
ser_got_byte
	phy
	ldy ser_first			; Get first byte in FIFO
	lda ser_buf,y
	inc ser_first			; Advance first byte of FIFO
	ply
	clc						; Indicate byte was got
	rts


;****************************************
;* ser_put_byte
;* Put a byte out
;* Input : A = Byte to put
;* Output : None
;* Regs affected : None
;****************************************
ser_put_byte
	pha						; Save A
;	phx
;	ldx #112				; Loop 112 times
ser_put_byte_wait				; Delay 2512 cycles (19200bps, 10 bits)
;	nop						; For 5.36Mhz clock
;	nop						; ~25 cycles per loop (10xnop+dex+bne)
;	nop						; 
;	nop						; 
;	nop						; 
;	nop						; 
;	nop						; 
;	nop						; 
;	nop						; 
;	nop						; 
;	dex						;
	lda SER_STATUS			; Check status register
	and #SER_TDRE			; Is transmit reg empty?
	beq ser_put_byte_wait	; Keep waiting if not
;	plx						; restore X
	pla						; Get A back
	sta SER_DATA			; Write the data
	rts


;****************************************
;* init_acia
;* ACIA initialisation (this is IO_3)
;* Input : None
;* Output : None
;* Regs affected : X
;****************************************
init_acia
	ldx #0
	stx ser_first			; Initialise FIFO buffer pointers
	stx ser_last
	stx SER_RESET			; Reset 6551
	ldx #0b00011111			; 19200 baud, 8 bits, 1 stop bit, internal clock		
	stx SER_CTL
	ldx #0b00001001			; No parity, no TX int plus RTS low, RX INT ENABLED, DTR
	stx SER_CMD
	ldx SER_STATUS			; Read status reg to clear stuff

	rts
