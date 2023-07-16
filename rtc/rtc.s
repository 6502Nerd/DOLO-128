;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  RTC.S
;*	Real time clock support.  Uses the DS12887 to provide
;*	time functions for use by the rest of the system, most
;*	notably for file date-time stamps.
;*	Just basic functions supported so far.
;*
;**********************************************************

	; ROM code
	code

mod_sz_rtc_s


;****************************************
;* rtc_write
;* Low level routine to write to a RTC location
;* Inputs; X=location, A=Value
;****************************************
rtc_write
	stx RTC_ADDR
	sta RTC_DATA
	rts


;****************************************
;* rtc_read
;* Low level routine to write to a RTC location
;* Inputs; X=location
;* Output; A=Value
;****************************************
rtc_read
	stx RTC_ADDR
	lda RTC_DATA
	rts


;****************************************
;* rtc_init
;* Initialise the RTC.  Check the VRT
;* and if suspect then offer option to
;* set date-time.
;* Check NV ram and warn if bad
;****************************************
rtc_init
	; No interrupts
	ldx #RTC_REGC
	lda #0
	jsr rtc_write
	
;	; Clear alarm bytes
;	lda #0
;	ldx #RTC_SECA
;	jsr rtc_write
;	ldx #RTC_MINA
;	jsr rtc_write
;	ldx #RTC_HRA
;	jsr rtc_write
;	; Also clear day of week (not used yet)
;	ldx #RTC_DOW
;	jsr rtc_write

	; Default is binary mode, 24 hour clock, no daylight saving
	ldx #RTC_REGB
	lda #RTC_DM | RTC_2412
	jsr rtc_write

	; Make sure clock is ticking
	ldx #RTC_REGA
	lda #0b00100000			; Magic number to start the oscillator
	jsr rtc_write
	
	; Check VRT - if zero then bad battery / RAM!
	ldx #RTC_REGD
	jsr rtc_read
	bmi rtc_badbattery_ok
	jsr rtc_badbattery
rtc_badbattery_ok
	; Check NV ram - if C=1 then corrupted!
	jsr rtc_nvvalid
	bcs rtc_badnvram
	
	;C=0
	rts

;****************************************
;* rtc_badbattery
;* Warn of bad battery and choice to set date/time
;****************************************
rtc_badbattery_msg
	db "Warning, RTC battery issue.",UTF_CR,0
	
rtc_badbattery
	; Print message
	ldx #lo(rtc_badbattery_msg)
	lda #hi(rtc_badbattery_msg)
	jsr io_print_line
	; Signifiy bad battery
	sec
	rts

;****************************************
;* rtc_badnvram
;* Warn of bad NV ram
;****************************************
rtc_badnvram_msg
	db "Warning, NV RAM checksum bad.",UTF_CR,0

rtc_badnvram
	; Print message
	ldx #lo(rtc_badnvram_msg)
	lda #hi(rtc_badnvram_msg)
	jsr io_print_line
	; Signify bad NV ram
	sec
	rts


;****************************************
;* rtc_freezeupdate
;* Stop time and date buffer updating
;****************************************
rtc_freezeupdate
	ldx #RTC_REGB
	lda #RTC_SET | RTC_DM | RTC_2412
	jmp rtc_write


;****************************************
;* rtc_resumeupdate
;* Resume time and date buffer updating
;****************************************
rtc_resumeupdate
	ldx #RTC_REGB
	lda #RTC_DM | RTC_2412
	jmp rtc_write


;****************************************
;* rtc_setdatetime
;* Set the date and time
;****************************************
rtc_date_msg
	db "Enter date dd/mm/yy : ",0
rtc_time_msg
	db "Enter time hh/mm/ss : ",0
rtc_notset_msg
	db "Not set",UTF_CR,0
rtc_setdatetime
	jsr rtc_freezeupdate
	; Message for get date
	ldx #lo(rtc_date_msg)
	lda #hi(rtc_date_msg)
	jsr io_print_line
	; Input date to the scratch buffer
	sec								; Echo
	ldx #lo(scratch)				; Serial input buffer for the string
	lda #hi(scratch)
	ldy #10
	jsr io_read_line
	cpy #8							; Must be 8 characters
	bne rtc_dtnotset				; else don't set
	ldx #0							; Buffer is page aligned, pos 0=day
	lda buf_adr+1
	jsr rtc_dtstringconvert
	bcs rtc_dtnotset
	; Ok now update the date from tmp_b,+1,+2
	ldx #RTC_DAY
	lda tmp_b
	jsr rtc_write
	ldx #RTC_MTH
	lda tmp_b+1
	jsr rtc_write
	ldx #RTC_YR
	lda tmp_b+2
	jsr rtc_write

	; Message for get time
	ldx #lo(rtc_time_msg)
	lda #hi(rtc_time_msg)
	jsr io_print_line
	; Input date to the scratch buffer
	sec								; Echo
	ldx #lo(scratch)				; Serial input buffer for the string
	lda #hi(scratch)
	ldy #10
	jsr io_read_line
	cpy #8							; Must be 8 characters
	bne rtc_dtnotset				; else don't set
	ldx #0							; Buffer is page aligned, pos 0=hr
	lda buf_adr+1
	jsr rtc_dtstringconvert
	bcs rtc_dtnotset
	; Ok now update the time from tmp_b,+1,+2
	ldx #RTC_HR
	lda tmp_b
	jsr rtc_write
	ldx #RTC_MIN
	lda tmp_b+1
	jsr rtc_write
	ldx #RTC_SEC
	lda tmp_b+2
	jsr rtc_write
	jsr rtc_resumeupdate
	; Signify time set OK
	clc
	rts
rtc_dtnotset
	; Message for get date
	ldx #lo(rtc_notset_msg)
	lda #hi(rtc_notset_msg)
	jsr io_print_line
	jsr rtc_resumeupdate
	; Signify time not set
	sec
	rts


;****************************************
;* rtc_ptrplus3
;* Add 3 to tmp_v1 ptr, result in tmp_v1 + X,A
;****************************************
rtc_ptrplus3
	clc
	lda tmp_v1
	adc #3
	sta tmp_v1
	tax
	lda tmp_v1+1
	adc #0
	sta tmp_v1+1
	rts


;**************************************
;* rtc_dtstringconvert
;* Convert a PP:QQ:RR string
;* Starting at X,A
;****************************************
rtc_dtstringconvert
	; X,A is base of string pointer
	stx tmp_v1						
	sta tmp_v1+1
	jsr con_dec_to_a				; Convert day of month
	bcs rtc_dtbadstring
	lda num_a						; Get converted number
	sta tmp_b						; Save day of month

	jsr rtc_ptrplus3				; +3 to base for month
	jsr con_dec_to_a				; Convert month
	bcs rtc_dtbadstring
	lda num_a						; Get converted number
	sta tmp_b+1						; Save month

	jsr rtc_ptrplus3				; +3 to base for month
	jsr con_dec_to_a				; Convert year
	bcs rtc_dtbadstring
	lda num_a						; Get converted number
	sta tmp_b+2						; Save year
rtc_dtbadstring
	rts


;**************************************
;* rtc_gettimedate
;* Get time and put in to 6 bytes in location X,A
;* Order is : HMSDMY
;**************************************
rtc_gettimedate
	stx tmp_v1
	sta tmp_v1+1
	ldy #0
	jsr rtc_freezeupdate
	ldx #RTC_HR
	jsr rtc_read
	sta (tmp_v1),y
	iny
	ldx #RTC_MIN
	jsr rtc_read
	sta (tmp_v1),y
	iny
	ldx #RTC_SEC
	jsr rtc_read
	sta (tmp_v1),y
	iny
	ldx #RTC_DAY
	jsr rtc_read
	sta (tmp_v1),y
	iny
	ldx #RTC_MTH
	jsr rtc_read
	sta (tmp_v1),y
	iny
	ldx #RTC_YR
	jsr rtc_read
	sta (tmp_v1),y
	jsr rtc_resumeupdate

;**************************************
;* rtc_nvvalid
;* Validate nvram checksum
;* C=1 means ERROR
;* Simple 8 bit sum of all bytes should
;* result in a zero. Partial sum carry
;* is used.
;* Uses A,X
;**************************************
rtc_nvvalid
	ldx #14
	lda #0
rtc_nvvalid_loop
	stx RTC_ADDR
	clc
	adc RTC_DATA
	inx
	cpx #NV_RAMSZ+1
	bne rtc_nvvalid_loop
	; A-1 will be C=1 if A>=1
	cmp #1
	rts

;**************************************
;* rtc_nvwrite
;* Write to nvram location X, value A
;* Checksum (byte 127) is also updated
;**************************************
rtc_nvwrite
	; Write to required nv location
	jsr rtc_write
	; Zero out checksum location
	ldx #NV_RAMSZ
	lda #0
	jsr rtc_write
	; Get new checksum by calling validator
	jsr rtc_nvvalid
	; Calculate checksum by making 2s complement
	eor #0xff
	clc
	adc #1
	; Write new checksum
	ldx #NV_RAMSZ
	jsr rtc_write
	rts

;**************************************
;* rtc_nvread
;* Read from nvram location X
;* Value in A
;* C=1 if checksum failed
;**************************************
rtc_nvread
	; Read nv location
	jsr rtc_read
	; Remember while validating checksum
	pha
	; Validate checksum (C=0 if OK)
	jsr rtc_nvvalid
	; Retrieve the location read
	pla
	; C=0 if OK and A is valid
	rts

mod_sz_rtc_e

