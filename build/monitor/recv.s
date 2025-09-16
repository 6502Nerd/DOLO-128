;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  RECV.S
;*	Part of monitor - receive file from serial
;*
;**********************************************************

recv_buffer				= df_rtstck
recv_csum				= df_linbuff
recv_fopen				= df_linbuff+1
recv_szlo				= df_linbuff+2
recv_szhi				= df_linbuff+3


; This is what a block looks like
	struct recv_block
	ds recv_block_number,1
	ds recv_block_payload_sz,1
	ds recv_block_payload,250
	ds recv_block_csum,1
	end struct


recv_wait_msg
	db "?",CRSR_LEFT,0
recv_done_msg
	db UTF_CR,0
recv_error_msg
	db UTF_CR,"RECV error",UTF_CR,0
recv_col1_msg
	db CRSR_UP,UTF_CR," ",0
recv_8blanks_msg
	db "        ",0
recv_closed_file_msg
	db CRSR_UP,UTF_CR,"+",0


; Macro to load X,A with message address then print it to io device (screen)
_recv_print macro msg
	ldx #lo(msg)
	lda #hi(msg)
	jsr io_print_line
	endm

; Print block number in X,A
recv_print_block
	phx
	pha
	_recv_print recv_col1_msg
	pla
	plx
	clc					; Leading zeros=false
	jmp print_a_to_d

;****************************************
;* cmd_recv
;* Receive file from serial and save to sd card
;* Input : cmd_lo, cmd_hi, A
;* Output : None
;* Regs affected : 
;****************************************
cmd_recv
	; Initialise file handle flag to nothing open
	stz recv_fopen
	; Zero out bytes received count
	stz recv_szlo
	stz recv_szhi
	; Flush the buffer - means that homebrew receive side starts first
	jsr recv_flush
	_recv_print recv_wait_msg
cmd_recv_get_block
	; Get header byte
	jsr recv_get_block_start
	; Check if ETB (done)
	cmp #UTF_ETB
	beq cmd_recv_done
	; Else must be SOH to get the block
	jsr recv_get_block
	; If bad then don't process the block
	bcs cmd_recv_error
	jsr recv_process_block
	; If processed block bad then error
	bcs cmd_recv_error
	; Else to get another block header
	jmp cmd_recv_get_block
cmd_recv_error
	_recv_print recv_error_msg
cmd_recv_done
	; Only close a file if it was open
	lda recv_fopen
	beq cmd_recv_skip_close
	_recv_print recv_closed_file_msg
	jsr _fs_close_w
cmd_recv_skip_close
	_recv_print recv_done_msg
	clc
	rts

; Keep getting bytes from the serial device until empty
recv_flush
	; C=0 means asynchronous
	clc
	jsr ser_get_byte
	bcc recv_flush
	; until C=1
	rts

; Wait for start or end of transmission (SOH, ETB)
recv_get_block_start
	; C=1 means synchronous
	sec
	jsr ser_get_byte
	cmp #UTF_SOH				; if SOH then reply with ACk to indicate ready for block
	beq recv_get_block_fin
	cmp #UTF_ETB				; if not ETB then keep checking!
	bne recv_get_block_start
recv_get_block_fin
	pha
	lda #UTF_ACK
	jsr ser_put_byte
	; SOH or ETB byte returned to caller
	pla
	rts

; Get block
recv_get_block
	; Initialise running checksum
	stz recv_csum
	ldx #0
recv_get_block_byte
	; Get byte, C=1 means synchronous
	sec
	jsr ser_get_byte
	sta recv_buffer,x
	; Add to checksum total
	clc
	adc recv_csum
	sta recv_csum
	inx
	; Keep going for the size of a block structure
	cpx #recv_block
	bne recv_get_block_byte
	; check running csum = 0
	lda recv_csum
	; if Z=1 then block is ok so send ACK
	bne recv_bad_block
	lda #UTF_ACK
	jsr ser_put_byte
	; C=0 means good block received
	clc
	rts
recv_bad_block
	; If not Z then block is bad so send NACK
	lda #UTF_NACK
	jsr ser_get_byte
	; C=1 means bad block received
	sec
	rts


; Process received block
; Block zero is meta data block, else data block
recv_process_block
	ldx recv_buffer+recv_block_number
	beq recv_process_block0
	jmp recv_process_blockn


; Process block zero meta data
; After block # and payload size:
;  zero terminated file name starting at position 2 (zero indexed)
;  zero terminated directory from root
;  final additional zero to indicate no more directories
recv_process_block0
	_recv_print recv_8blanks_msg
	ldy #recv_block_payload
	; Jump over the filename
recv_find_fname_end
	lda recv_buffer,y
	iny
	cmp #0
	bne recv_find_fname_end
recv_process_path
	; Load X,A with recv_buffer pointer indexed by Y
	; This gives the directory name to change to
	tya
	clc
	adc #lo(recv_buffer)
	tax
	lda #hi(recv_buffer)
	adc #0
	; Print this directory name
	pha
	phx
	phy
	jsr io_print_line

	lda #'/'
	jsr io_put_ch	; Forward slash after dir name
	ply
	plx
	pla
	; Change to this directory
	jsr _fs_chdir_w
	bcs block0_error
	; Now find end of this directory
recv_find_dir_end
	lda recv_buffer,y
	iny
	cmp #0
	bne recv_find_dir_end
	; If next byte is zero then done
	lda recv_buffer,y
	bne recv_process_path
	; Now we are in the right folder to write the file
	; Need to open the file using the filename at start of payload
	; Get X,A to point to this
	clc
	lda #recv_block_payload
	adc #lo(recv_buffer)
	tax
	lda #hi(recv_buffer)
	adc #0
	; Print filename
	pha
	phx
	jsr io_print_line
	plx
	pla
	; Now open for write
	jsr _fs_open_write_w
	bcs block0_error
	; Set flag indicating file is opened
	inc recv_fopen
block0_error
	rts

; Process data block payload
recv_process_blockn
;	_recv_print recv_got_block_msg
	clc
	lda recv_buffer+recv_block_payload_sz
	adc recv_szlo
	sta recv_szlo
	tax
	lda recv_szhi
	adc #0
	sta recv_szhi	
	jsr recv_print_block
	ldx #0
recv_process_blockn_byte
	; Get byte from buffer
	lda recv_buffer+recv_block_payload,x
	; Write to file previously opened for write
	jsr _fs_put_byte_w
	inx
	; Processed all bytes?
	cpx recv_buffer+recv_block_payload_sz
	bne recv_process_blockn_byte
	clc
	rts
