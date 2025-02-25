;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  CMD.S
;*	Simple monitor.
;*
;**********************************************************

CMD_ERR_NOERROR			= 0x00
CMD_ERR_NOTFOUND		= 0x01
CMD_ERR_PARM			= 0x02
CMD_ERR_VAL				= 0x03
cmd_lo					= df_currdat
cmd_hi					= (df_currdat+1)
cmd_mem					= df_datoff
cmd_msg_ptr				= df_lineptr

	; ROM code
	code  

; Immediate call to monitor from outside of monitor shell
cmd_immediate
	jsr cmd_parse				; Find command and execute
	bcs cmd_imerror				; Carry set = error condition
	rts
cmd_imerror
	jmp cmd_print_error

command_line
	lda #0						; Initialise monitor
	sta cmd_lo					; Monitor address lo
	sta cmd_hi					; Monitor address hi
	sta cmd_mem					; Memory = 0 RAM, 1 = VRAM
	ldy #160					; Maximum line length
	sty buf_sz

cmd_ready
	_println msg_ready

	sec							; Set carry flag = echo characters
	ldx #lo(df_linbuff)
	lda #hi(df_linbuff)
	ldy #80
	jsr io_read_line			; Get a command line
	jsr cmd_parse				; Find command and execute
	bcs cmd_error				; Carry set = error condition
	jmp cmd_ready

cmd_error
	lda errno
	bpl cmd_skip_quit
	stz errno					; Clear error
	clc							; Clear carry
	rts							; Return to caller
cmd_skip_quit	
	jsr cmd_print_error
	jmp cmd_ready

;****************************************
;* cmd_print_error
;* Given error code and Y offset in to buffer
;* print the error message
;* Input : errno, Y
;* Regs affected :
;****************************************
cmd_print_error
	pha
	phy
	lda errno
	asl a
	tay
	ldx cmd_error_messages,y
	lda cmd_error_messages+1,y
	jsr io_print_line
	lda #' '
	jsr io_put_ch
	pla								; Pull Y off stack
	pha								; And put it back
	jsr str_a_to_x
	jsr io_put_ch
	txa
	jsr io_put_ch
	lda #UTF_CR
	jsr io_put_ch
	
	ply
	pla
	rts
	

;****************************************
;* cmd_parse
;* Parse the command line in the io buffer
;* Input : buflo, bufhi
;* Output : y = start of first parm byte
;*          x = index to routine pointer
;* Regs affected : A
;****************************************
cmd_parse
	pha
	phx
	
	ldx #0
find_cmd_loop
	ldy #0
	lda df_linbuff,y		; Need to check for ! now
	cmp #'!'
	bne find_cmd_byte
	iny						; Skip over ! if needed
find_cmd_byte
	lda cmd_list,x			; Check the command list
	cmp #0x80				; If not end of this command in list
	bne cmd_do_match		; then do the check
	lda df_linbuff,y		; Check the command line
	beq cmd_found			; If zero then found
	cmp #' '				; If space then
	beq cmd_found			; also found
cmd_do_match				; If here then line <> 0/space and list <> 0x80
	lda df_linbuff,y		; Get char from command buffer
	ora #0x20				; Make lower case
	cmp cmd_list,x			; Compare with char from command list	
	bne cmd_no_match		; Different = command does not match
	iny						; Advance command buffer and list
	inx
	bra find_cmd_byte		; Go check the next bytes
cmd_no_match				; A command didn't match, so find the next one
	lda cmd_list,x			; Get the non-matching command list byte
	cmp #0x80				; If already at command terminator then
	beq cmd_next_cmd		; set up for next command
	cmp #0xff				; If end of command list
	beq cmd_not_found		; then not found
	inx						; Else check next char
	bra cmd_no_match
cmd_next_cmd
	inx						; Jump over 0x80
	inx						; Jump over command address
	inx
	bra find_cmd_loop		; Check for match again

cmd_not_found
	lda #CMD_ERR_NOTFOUND
	sta errno
	pla
	plx
	sec
	rts
	
cmd_found					; Found the command
	lda cmd_list+1,x		; Low byte of jump pointer
	sta tmp_v1				; Store in temp location
	lda cmd_list+2,x		; High byte of jump pointer
	sta tmp_v1+1			; Store in temp location
	pla
	plx
	jmp (tmp_v1)			; Jump to command (Y points at last byte of cmd+1)
	
;****************************************
;* cmd_memtype
;* Set the memory type to V or M
;* Input : buflo, bufhi
;* Output : y = start of first parm byte
;*          x = index to routine pointer
;* Regs affected : A
;****************************************
cmd_memtype
	pha
	clc
	jsr cmd_parse_next_parm
	lda #CMD_ERR_PARM
	bcs cmd_memtype_err
	lda df_linbuff,y
	ora #0x20
	cmp #'v'
	beq cmd_setmemtypeV
	cmp #'m'
	beq cmd_setmemtypeM
	lda #CMD_ERR_VAL
	bra cmd_memtype_err
cmd_setmemtypeV
	lda #1
	sta cmd_mem
	bra cmd_memtypeFin
cmd_setmemtypeM
	stz cmd_mem
cmd_memtypeFin
	pla
	clc
	rts
cmd_memtype_err
	sta errno
	sec
	pla
	rts
	
;****************************************
;* cmd_setmem
;* Set the memory at address AAAA to byte string
;* Input : buflo, bufhi
;* Output : y = start of first parm byte
;*          x = index to routine pointer
;* Regs affected : A
;****************************************
cmd_setmem
	pha
	phx
	
	clc
	jsr cmd_parse_next_parm
	bcs cmd_setmem_err
	jsr cmd_parse_word
	bcs cmd_setmem_err
	stx cmd_lo
	sta cmd_hi
	jsr cmd_parse_next_parm		; Should be at least 1 byte to set
	bcs cmd_setmem_err
cmd_setmem_byte
	jsr cmd_parse_byte
	bcs cmd_setmem_err
	jsr cmd_poke				; Poke A in to cmd_lo, hi
	jsr cmd_incmem
	jsr cmd_parse_next_parm		; Try and find another parm
	bcc cmd_setmem_byte			; Process if found, else fin
cmd_setmemFin
	clc
	plx
	pla
	rts
cmd_setmem_err
	sec
	plx
	pla
	rts


;****************************************
;* cmd_dumpmem
;* Dump memory at address AAAA
;* Input : buflo, bufhi
;* Output : y = start of first parm byte
;* Regs affected : A
;****************************************
cmd_dumpmem
	pha
	phx
	phy

	clc
	jsr cmd_parse_next_parm
	bcs cmd_dumpmem_err
	jsr cmd_parse_word			; Get hi byte of word
	bcs cmd_dumpmem_err
	jsr cmd_parse_next_parm		; Should cause error, no parms!
	bcc cmd_dumpmem_parm_err
	stx cmd_lo
	sta cmd_hi
	bra cmd_dumpmem_block		; Skip over error code to start of dump
cmd_dumpmem_parm_err
	lda #CMD_ERR_PARM
	sta errno
cmd_dumpmem_err
	ply
	plx
	pla
	sec
	rts
cmd_dumpmem_block
	lda cmd_hi					; Show the address
	jsr str_a_to_x
	jsr io_put_ch
	txa
	jsr io_put_ch
	lda cmd_lo
	jsr str_a_to_x
	jsr io_put_ch
	txa
	jsr io_put_ch
	lda #' '
	jsr io_put_ch
	
	ldy #8						; 8 Bytes per line
cmd_dumpmem_byte
	jsr cmd_peek
	jsr str_a_to_x
	jsr io_put_ch
	txa
	jsr io_put_ch
	lda #' '
	jsr io_put_ch
	jsr cmd_incmem
	dey
	bne cmd_dumpmem_byte
cmd_dumpmemASCII
	sec
	lda cmd_lo
	sbc #8
	sta cmd_lo
	lda cmd_hi
	sbc #0
	sta cmd_hi
	
	lda #' '
	jsr io_put_ch
	jsr io_put_ch
	ldy #8						; 8 Bytes per line
cmd_dumpmem_ascii
	jsr cmd_peek
	cmp #' '					; <32 is unprintable
	bcs cmd_dump_skip_ctrl
	lda #'.'					; Replace with dot
cmd_dump_skip_ctrl
	cmp #UTF_DEL				; >= DEL is unprintable
	bcc cmd_dump_skip_del
	lda #'.'					; Replace with dot
cmd_dump_skip_del	
	jsr io_put_ch
	jsr cmd_incmem
	dey
	bne cmd_dumpmem_ascii
	sec
	jsr io_get_ch
	cmp #UTF_CR
	bne cmd_dumpmemFin
	jsr io_put_ch
	bra cmd_dumpmem_block
cmd_dumpmemFin
	lda #UTF_CR
	jsr io_put_ch
	ply
	plx
	pla
	clc
	rts
	

;****************************************
;* cmd_sector
;* Load sector
;* Input : buflo, bufhi
;* Output : y = start of first parm byte
;* Regs affected : A
;****************************************
cmd_sector
	pha
	phx
	phy

	clc
	
	jsr cmd_parse_byte			; Get read or write indicator
	bcs cmd_sector_err
	pha							; Save the indicator
	
	jsr cmd_parse_word			; Get hi byte of word
	bcs cmd_sector_errl

	stx sd_sect+0				; Initialise the sector
	sta sd_sect+1
	stz sd_sect+2
	stz sd_sect+3

	jsr cmd_parse_next_parm		; Should cause error, no parms!
	bcc cmd_sector_errl

	lda #hi(sd_buf)				; Save/Load from sd_buf

	plx							; Read or write?
	cpx #0x00
	bne cmd_sector_skip00
	jsr _sd_sendcmd17
	bra cmd_sector_done
cmd_sector_skip00
	cpx #0x01
	bne cmd_sector_skip01
	jsr _sd_sendcmd24
	bra cmd_sector_done
cmd_sector_skip01
	cpx #0xff
	bne cmd_sector_skipff
	jsr _sd_sendcmd17
	jsr _sd_sendcmd24
	bra cmd_sector_done
cmd_sector_skipff
	cpx #0xfe
	bne cmd_sector_done
	jsr _sd_sendcmd24
	jsr _sd_sendcmd17
	
cmd_sector_done	
	ply
	plx
	pla
	clc
	rts
cmd_sector_errl
	pla
cmd_sector_err
	sta errno
	ply
	plx
	pla
	sec
	rts
	
	
;****************************************
;* cmd_quit
;* To quit set err=255 and C=1
;****************************************
cmd_dflat
	lda #0xff
	sta errno
	sec
	rts
	
;****************************************
;* cmd_incmem
;* Increment pointer
;* Input : cmd_lo, cmd_hi
;* Output : cmd_lo, cmd_hi
;* Regs affected : 
;****************************************
cmd_incmem
	inc cmd_lo
	bne cmd_skipincmemhi
	inc cmd_hi
cmd_skipincmemhi
	rts
	
;****************************************
;* cmd_peek
;* Read byte
;* Input : cmd_lo, cmd_hi
;* Output : A
;* Regs affected : 
;****************************************
cmd_peek
	lda cmd_mem
	bne cmd_peek_vram
	lda (cmd_lo)
	rts
cmd_peek_vram
	phx
	ldx cmd_lo
	lda cmd_hi
	jsr _vdp_peek
	plx
	rts
	
;****************************************
;* cmd_poke
;* Read byte
;* Input : cmd_lo, cmd_hi, A
;* Output : A
;* Regs affected : 
;****************************************
cmd_poke
	pha
	lda cmd_mem
	bne cmd_poke_vram
	pla
	sta (cmd_lo)
	rts
cmd_poke_vram
	pla
	phx
	phy
	ldx cmd_lo
	ldy cmd_hi
	jsr _vdp_poke
	ply
	plx
	rts


;****************************************
;* cmd_time
;* Set date and time
;* Input : cmd_lo, cmd_hi, A
;* Output : None
;* Regs affected : 
;****************************************
cmd_time
	jsr _rtc_setdatetime
	rts

;****************************************
;* cmd_parse_byte
;* Find 2 char hex byte
;* Input : buflo, bufhi, y offset
;* Output : y = char after hex byte, A = value
;* Regs affected : A,Y
;****************************************
cmd_parse_byte
	phx
	jsr cmd_parse_next_parm	; Find the next parameter
	bcs cmd_parse_byte_err
	lda df_linbuff,y		; Get hi nibble of high byte
	pha						; Save on stack
	iny
	lda df_linbuff,y		; Get lo nibble of high byte
	beq cmd_parse_byte_errl	; If no char then error but pull byte
	tax						; Lo nibble goes to X
	pla						; Restore hi nibble
	jsr str_x_to_a			; Convert from hex to A
	bcs cmd_parse_byte_err	; If error then stop
	iny						; Point to next char
	clc
	plx
	rts
cmd_parse_byte_errl
	pla						; Pull low nibble off
cmd_parse_byte_err
	lda #CMD_ERR_VAL		; Basic value error
	sta errno
	sec
	plx
	rts

;****************************************
;* cmd_parse_word
;* Find 4 char hex word
;* Input : buflo, bufhi, y offset
;* Output : y = char after hex byte, A = hi, X = lo value
;* Regs affected : A,X,Y
;****************************************
cmd_parse_word
	jsr cmd_parse_next_parm		; Find the next parameter
	bcs cmd_word_err
	jsr cmd_parse_byte			; Get hi byte of word
	bcs cmd_word_err
	pha							; Save hi byte of word
	jsr cmd_parse_byte			; Get lo byte of word
	bcs cmd_word_errl
	tax							; Put in X
	pla							; Get high byte back
	clc
	rts
cmd_word_errl
	pla							; Pull off stack
cmd_word_err
	lda #CMD_ERR_VAL
	sta errno
	sec
	rts

;****************************************
;* cmd_parse_next_parm
;* Find next non-white space
;* Input : buflo, bufhi, y offset
;* Output : y = start of first parm byte
;* Regs affected : A
;****************************************
cmd_parse_next_parm
	pha
cmd_find_parm
	lda df_linbuff,y
	iny
	cmp #0					; End of command line?
	beq cmd_next_parm_err	; ie no parms
	cmp #' '				; Ignore space
	beq cmd_find_parm
	dey						; Go back 1 to parm start
	pla
	clc
	rts
cmd_next_parm_err
	dey						; Go back 1 to end of line
	lda #CMD_ERR_PARM
	sta errno
	pla
	sec
	rts

;****************************************
;* cmd_dcolour
;* Set default boot up colour
;****************************************
cmd_dcolour
	phx
	pha
	jsr cmd_parse_byte
	bcs cmd_dcolour_fin
	ldx #NV_COLOUR
	jsr _rtc_nvwrite
	clc
cmd_dcolour_fin
	pla
	plx
	rts

;****************************************
;* cmd_dmode
;* Set default boot up mode
;****************************************
cmd_dmode
	phx
	pha
	jsr cmd_parse_byte
	bcs cmd_dmode_fin
	ldx #NV_COLOUR
	jsr _rtc_nvwrite
	clc
cmd_dmode_fin
	pla
	plx
	rts

;****************************************
;* cmd_help
;* Display help text
;****************************************
cmd_help
	lda #lo(msg_help)
	sta cmd_msg_ptr
	lda #hi(msg_help)
	sta cmd_msg_ptr+1
	ldy #0
cmd_msg_char
	lda (cmd_msg_ptr),y
	beq cmd_msg_line_done
	jsr io_put_ch
	iny
	bne cmd_msg_char
cmd_msg_line_done
	iny
	clc
	tya
	adc cmd_msg_ptr
	sta cmd_msg_ptr
	lda cmd_msg_ptr+1
	adc #0
	sta cmd_msg_ptr+1
	ldy #0
	lda (cmd_msg_ptr),y
	bne cmd_msg_char
	rts


cmd_list
	db "memtype",	0x80,	lo(cmd_memtype), 	hi(cmd_memtype)
	db "dump", 		0x80, 	lo(cmd_dumpmem), 	hi(cmd_dumpmem)
	db "set", 		0x80,	lo(cmd_setmem), 	hi(cmd_setmem)
	db "sector",	0x80,	lo(cmd_sector),		hi(cmd_sector)
	db "quit",		0x80,	lo(cmd_dflat),		hi(cmd_dflat)
	db "time",		0x80,	lo(cmd_time),		hi(cmd_time)
	db "recv",		0x80,	lo(cmd_recv),		hi(cmd_recv)
	db "dmode",		0x80,	lo(cmd_dmode),		hi(cmd_dmode)
	db "dcolour",	0x80,	lo(cmd_dcolour),	hi(cmd_dcolour)
	db "help",		0x80,	lo(cmd_help),		hi(cmd_help)
	db 0x00,		0x00,	0xff


cmd_error_messages
	dw msg_errmsg_none
	dw msg_errmsg_notfound
	dw msg_errmsg_parm
	dw msg_errmsg_val

msg_ready				db "#>",0
msg_errmsg_none			db "No error",0
msg_errmsg_notfound		db "Command not found",0
msg_errmsg_parm			db "Parameter error",0
msg_errmsg_val			db "Illegal value",0

msg_help				db "Monitor commands:",UTF_CR,0
						db "recv            RX file from PC",UTF_CR,0
						db "memtype v|m     Select VRAM|RAM",UTF_CR,0
						db "dump xxxx       Dump memory",UTF_CR,0
						db "set  xxxx [zz]* Set memory",UTF_CR,0
						db "time            Set clock",UTF_CR,0
						db "dmode xx        Default mode",UTF_CR,0
						db "dcolour xx      Default colour",UTF_CR,0
						db "sector rw xxxx  SD sector",UTF_CR,0
						db "quit            Have a guess",UTF_CR,0,0



	include "monitor\recv.s"

