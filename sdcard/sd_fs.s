;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  SD_FS.S
;*  FAT16 filesystem module.  Implements a basic FAT16
;*  filesystem to enable mass storage support.
;*  I've been a bit naughty in that I have assumed a 1GB
;*  sd card size and sector 0 is the MBR.  This is not
;*  always the case, but it works for me so I couldn't at
;*  the time be asked to sort it out. I may fix this for
;*  more general use at some point..
;*  The filesystem now supports sub directories and
;*  implements the folling:
;*  - load a file
;*  - save a file
;*  - delete a file from the card
;*  - perform a directory listing
;*  - change to subdirectory
;*  I have to say I am pretty pleased with this, took a lot
;*  of reading and research!
;*
;**********************************************************


	; ROM code
	code

mod_sz_sd_fs_s

	include "sdcard\sd_fs.i"

;****************************************
;* init_fs
;* Initialise filesystem - after sd card!
;* Input : None
;* Output : None
;* Regs affected : None
;****************************************
init_fs
	ldx sd_status
	beq init_fs_do
	_println msg_noinit_fs
	rts

init_fs_do
	_println msg_initialising_fs

	;Load MBR sector 0
	ldx #0x03					; Init sector to 0 (MBR)
init_fs_clr_sect
	stz sd_sect,x
	dex
	bpl init_fs_clr_sect

	lda #hi(sd_buf)				; Read in to the buffer
	jsr sd_sendcmd17			; Call read block

	;Find sector of partition 1
	ldx #0x03					; Get partition 1
init_fs_get_part1
	lda sd_buf+MBR_BootPart1,x
	sta sd_sect,x
	sta fs_bootsect,x			; This is also the 'bootsector' (i.e. primary partition)
	dex
	bpl init_fs_get_part1
	; Get partition 1 sector
	lda #hi(sd_buf)				; Read in to the buffer
	jsr sd_sendcmd17			; Call read block

	; Calculate start of FAT tables
	; Assuming there are about 64k clusters
	; Each cluster assumed to be 32k sectors
	; Each sector is 512 bytes (0.5k)
	; Giving 64k x 32k x 0.5 ~ 1GB storage
	clc
	lda fs_bootsect
	adc sd_buf+MBR_ResvSect
	sta fs_fatsect
	lda fs_bootsect+1
	adc sd_buf+MBR_ResvSect+1
	sta fs_fatsect+1
	stz fs_fatsect+2
	stz fs_fatsect+3
	
	; Calculate start of Root Directory
	lda sd_buf+MBR_SectPerFAT	; Initialise to 2 * SectPerFAT
	asl a
	sta fs_rootsect
	lda sd_buf+MBR_SectPerFAT+1
	rol a
	sta fs_rootsect+1
	stz fs_rootsect+2
	stz fs_rootsect+3

	; Now add FAT offset
	clc
	ldx #0x00
	ldy #4
fs_init_add_fat
	lda fs_fatsect,x
	adc fs_rootsect,x
	sta fs_rootsect,x
	inx
	dey
	bne fs_init_add_fat
	
	; Calculate start of data area
	; Assuming 512 root dir entries
	; Each entry = 32 bytes
	; Divided by bytes per sector
	; to get sector count
	lda #32						; (512*32)/512 = 32
	sta fs_datasect
	stz fs_datasect+1
	stz fs_datasect+2
	stz fs_datasect+3

	; Now add root directory offset
	clc
	ldx #0x00
	ldy #4
fs_init_data
	lda fs_rootsect,x
	adc fs_datasect,x
	sta fs_datasect,x
	inx
	dey
	bne fs_init_data

	sec							; Now subtract 2 clusters worth of sector
	lda fs_datasect+0			; to enable easy use of clusters in main
	sbc #0x40					; FS handling routines
	sta fs_datasect+0			; Each cluster = 32 sectors
	lda fs_datasect+1			; Therefore take off 0x40 sectors from datasect
	sbc #0
	sta fs_datasect+1
	lda fs_datasect+2
	sbc #0
	sta fs_datasect+2
	lda fs_datasect+3
	sbc #0
	sta fs_datasect+3

	; Go to root directory using zero cluster #
	stz fh_handle+FH_FirstClust
	stz fh_handle+FH_FirstClust+1
	jsr fs_chdir_direct
	
	rts


;****************************************
;* fs_getbyte_sd_buf
;* Given a populated SD buffer, get byte
;* Indexed by X,Y (X=lo,Y=hi) 
;* Input : X,Y make 9 bit index
;* Output : A=Byte
;* Regs affected : None
;****************************************
fs_getbyte_sd_buf
	; if bit 9<>0 then 2nd half of sd_buf
	tya
	and #1
	bne fs_getbyte_sd_buf_hi
	lda sd_buf,x
	rts
fs_getbyte_sd_buf_hi
	lda sd_buf+0x100,x
	rts


;****************************************
;* fs_putbyte_sd_buf
;* Given a populated SD buffer, put byte
;* Indexed by X,Y (X=lo,Y=hi), A=Val 
;* Input : X,Y make 9 bit index, A=byte
;* Output : None
;* Regs affected : None
;****************************************
fs_putbyte_sd_buf
	pha
	; if bit 9<>0 then 2nd half of sd_buf
	tya
	and #1
	bne fs_putbyte_sd_buf_hi
	pla
	sta sd_buf,x
	rts
fs_putbyte_sd_buf_hi
	pla
	sta sd_buf+0x100,x
	rts

;****************************************
;* fs_getword_sd_buf
;* Given a populated SD buffer, get word
;* Indexed by Y which is word aligned 
;* Input : Y=Word offset in to sd_buf
;* Output : X,A=Word
;* Regs affected : Y
;****************************************
fs_getword_sd_buf
	tya
	asl a
	tay
	bcs fs_getword_sd_buf_hi
	ldx sd_buf,y
	lda sd_buf+1,y
	rts
fs_getword_sd_buf_hi
	ldx sd_buf+0x100,y
	lda sd_buf+0x100+1,y
	rts


;****************************************
;* fs_putword_sd_buf
;* Given a populated SD buffer, put word
;* Indexed by Y which is word aligned 
;* Input : Y=Word offset in to sd_buf
;*         X,A=Word
;* Regs affected : Y
;****************************************
fs_putword_sd_buf
	pha
	tya
	asl a
	tay
	bcs fs_putword_sd_buf_hi
	txa
	sta sd_buf,y
	pla
	sta sd_buf+1,y
	rts
fs_putword_sd_buf_hi
	txa
	sta sd_buf+0x100,y
	pla
	sta sd_buf+0x100+1,y
	rts


;****************************************
;* fs_dir_root_start
;* Initialise ready to read root directory
;* Input : dirsect is current directory pointer
;* Output : None
;* Regs affected : None
;****************************************
fs_dir_root_start
	; Set SD sector to root directory
	ldx #0x03
fs_dir_set_sd
	lda fs_dirsect,x
	sta sd_sect,x
	dex
	bpl fs_dir_set_sd

	; SD buffer is where blocks will be read to
	stz sd_slo
	lda #hi(sd_buf)
	sta sd_shi

	; Load up first sector in to SD buf
	lda #hi(sd_buf)
	jsr sd_sendcmd17

	rts


;* Wrapper function preserving A,X,Y
fs_dir_root_start_w
	pha
	phx
	phy
	
	jsr fs_dir_root_start
	
	ply
	plx
	pla
	rts


;****************************************
;* fs_dir_find_entry
;* Read directory entry
;* Input : sd_slo, sd_shi : Pointer to directory entry in SD buffer
;* Input : C = 0 only find active files.  C = 1 find first available slot
;* Output : None
;* Regs affected : None
;****************************************
fs_dir_find_entry
	php							; Save C state for checking later
fs_dir_check_entry
	; Not LFN aware
	ldy #FAT_Attr				; Check attribute
	lda #0xce					; Any of H, S, V, I then skip
	and (sd_slo),y
	bne fs_dir_find_another
	ldy #FAT_Name				; Examine 1st byte of name
	lda (sd_slo),y
	plp							; Check C
	php
	bcc	fs_find_active_slot		; Looking to find an active file
	cmp #0						; Else looking for 0 or 0xe5
	beq fs_dir_found_empty
	cmp #0xe5
	beq fs_dir_found_empty
	bra fs_dir_find_another		; Else not an entry we're interested in
fs_find_active_slot
	cmp #0
	beq fs_dir_notfound			; If zero then no more entries
	cmp #0xe5					; Deleted entry?
	bne fs_dir_found_active
fs_dir_find_another
	jsr fs_dir_next_entry		; Advance read for next iteration
	bra fs_dir_check_entry

fs_dir_notfound					; No more entries
	plp							; Remove temp P from stack
	sec							; Set carry to indicate no more
	rts

fs_dir_found_active
	ldy #FATFileDesc-1			; Cache the sd entry to fs_direntry
fs_dir_copy_sd_entry_byte
	lda (sd_slo),y
	sta fs_direntry,y
	dey
	bpl fs_dir_copy_sd_entry_byte
fs_dir_found_empty
	jsr fs_dir_entry_to_fhandle	; Now copy to file handle area
	plp							; Remove temp P from stack
	clc							; Clear carry to indicate found
fs_dir_fin						; Finalise
	rts

;* Wrapper function preserving A,X,Y
fs_dir_find_entry_w
	pha
	phx
	phy
	
	jsr fs_dir_find_entry
	
	ply
	plx
	pla
	rts

	
;****************************************
;* fs_dir_next_entry
;* Jump to next directory entry (32 bytes)
;* Load next sector if required
;* Input : sd_slo, sd_shi : Pointer to directory entry in SD buffer
;* Output : None
;* Regs affected : None
;****************************************
fs_dir_next_entry
	clc							; Jump to next 32 byte entry
	lda sd_slo					; Update sd_slo, sd_shi
	adc #32
	sta sd_slo
	lda sd_shi
	adc #0
	sta sd_shi
	cmp #hi(sd_buf+0x200)		; If not at end of sector (beyond page 1)
	bne fs_dir_next_done		; then don't load next sector

	; Advance the sector
	ldx #0x00
	ldy #0x04
	sec
fs_dir_inc_sect
	lda sd_sect,x
	adc #0
	sta sd_sect,x
	inx
	dey
	bne fs_dir_inc_sect
	
	; Reset SD buffer  where blocks will be read to
	stz sd_slo
	lda #hi(sd_buf)
	sta sd_shi

	lda #hi(sd_buf)				; Goes in to sd_buf
	jsr sd_sendcmd17			; Load it

fs_dir_next_done
	rts

;* Wrapper function preserving A,X,Y
fs_dir_entry_next_w
	pha
	phx
	phy
	
	jsr fs_dir_next_entry
	
	ply
	plx
	pla
	rts


;****************************************
;* fs_dir_entry_to_fhandle
;* Copy directory entry from fs_direntry to fh_handle
;* Input : fs_direntry (32 bytes file descriptor from SD Card)
;* Output : None
;* Regs affected : None
;****************************************
fs_dir_entry_to_fhandle
	;* Translate name to a string in fhandle
	ldx #FH_Name				; Destination
	ldy #FAT_Name				; Source
fs_dir_get_fs_name_ch
	lda fs_direntry,y			; Get name char
	cmp #' '					; Don't copy space
	beq	fs_dir_skip_fs_name_ch
	cpy #FAT_Ext				; At extension?
	bne fs_dir_skip_fs_dot_ch
	pha
	lda #'.'					; Inject dot into handle
	sta fh_handle,x
	pla
	inx							; Advance past dot separator
fs_dir_skip_fs_dot_ch
	sta fh_handle,x				; Copy char to handle
	inx							; Advance handle
fs_dir_skip_fs_name_ch
	iny							; Source
	cpy #FAT_Attr				; Passed end of name?
	bne fs_dir_get_fs_name_ch
	stz fh_handle,x				; Put 0 (terminator)

	;* Attribute byte
	ldx #FH_Attr				; Point to where attribute will go
	ldy #FAT_Attr				; Point to where attribute comes from
	jsr fs_dir_entry_to_fh_byte

	;* File size
	ldx #FH_Size				; Point to where size will go
	ldy #FAT_FileSize			; Point to get size from
	jsr fs_dir_entry_to_fh_byte	; Copy 4 bytes
	jsr fs_dir_entry_to_fh_byte
	jsr fs_dir_entry_to_fh_byte
	jsr fs_dir_entry_to_fh_byte

	;* First cluster
	ldx #FH_FirstClust
	ldy	#FAT_FirstClust
	jsr fs_dir_entry_to_fh_byte	; Copy 2 bytes
	jsr fs_dir_entry_to_fh_byte

	;* Time and date - ignore ms and use modified date
	ldx #FH_TimeDate
	stz fh_handle,x
	inx							; Skip ms to time/date 4 bytes
	ldy	#FAT_ModTime			; Get modified time/date entry
	jsr fs_dir_entry_to_fh_byte	; Copy 4 bytes (2 bytes for time)
	jsr fs_dir_entry_to_fh_byte 
	jsr fs_dir_entry_to_fh_byte ; (2 bytes for date)
	jsr fs_dir_entry_to_fh_byte
	
	; Meta data - remember the parent directory
	ldx #0x03
fs_dir_dirsect_fh_byte
	lda fs_dirsect,x
	sta fh_handle+FH_DirSect,x
	dex
	bpl fs_dir_dirsect_fh_byte

	; Meta data - remember the offset in to the sd buffer, for writing back
	lda sd_slo
	sta fh_handle+FH_DirOffset
	lda sd_shi
	sta fh_handle+FH_DirOffset+1
	
	rts
	

;****************************************
;* fs_dir_entry_to_fh_byte
;* Copy fs_direntry bytes to fh_handle area
;* Input 	: y = offset in directory entry
;*		 	: x = offset in handle entry
;* Output 	: None
;* Regs affected : All
;****************************************
fs_dir_entry_to_fh_byte
	lda fs_direntry,y
	sta fh_handle,x
	iny
	inx
	rts

;****************************************
;* fs_dir_entry_to_sd
;* Copy fs_direntry bytes to sd card area
;* Index by sd_lo, sd_hi
;* Input	: None
;* Output 	: None
;* Regs affected : All
;****************************************
fs_dir_entry_to_sd
	ldx #FATFileDesc-1
fs_dir_entry_to_sd_byte
	lda fs_direntry,y
	sta fh_handle,x
	iny
	inx
	rts



;****************************************
;* fs_dir_fhandle_to_entry
;* Copy directory entry from fh_handle to fs_direntry 
;* Input : fs_fhandle 
;* Output : fs_direntry updated
;* Regs affected : None
;****************************************
fs_dir_fhandle_to_entry
	; Set to spaces (11 in total)
	ldy #10
	lda #' '
fs_dir_clear_entry
	sta fs_direntry+FAT_Name,y
	dey
	bpl fs_dir_clear_entry
	;* Translate name to a string in direntry
	ldx #FH_Name				; Source
	ldy #FAT_Name				; Destination
fs_dir_get_fh_name_ch
	lda fh_handle,x				; Get name char
	beq	fs_dir_do_attr			; Process attribute if end of string
	jsr fs_to_upper				; Case insensitive
	cmp #'.'					; Extension separator?
	bne fs_dir_skip_ext			; No, then normal char
	cpx #0						; If dot is first char
	beq fs_dir_skip_ext			; Then treat as normal char
	cpx #1						; If dot is not second char
	bne fs_dir_get_fh_dot		; Then treat as dot
	cmp fh_handle				; Was the first char dot?
	beq fs_dir_skip_ext			; Yes then treat as normal char
fs_dir_get_fh_dot
	ldy #FAT_Ext				; Move to ext position
	inx							; Jump over the dot
	bra fs_dir_get_fh_name_ch	; Try more chars
fs_dir_skip_ext					; Normal char processing
	sta fs_direntry,y			; Save it to direntry
	iny							; Advance entry index
	inx							; Advance string index
	cpy #FAT_Attr				; All name + ext done?
	bne fs_dir_get_fh_name_ch	; Try for another normal char
	;* Attribute byte
fs_dir_do_attr
	ldx #FH_Attr				; Point to where attribute will go
	ldy #FAT_Attr				; Point to where attribute comes from
	jsr fs_dir_fh_to_entry_byte

	;* File size
fs_dir_fh_size
	ldx #FH_Size				; Point to where size will go
	ldy #FAT_FileSize			; Point to get size from
	jsr fs_dir_fh_to_entry_byte	; Copy 4 bytes
	jsr fs_dir_fh_to_entry_byte
	jsr fs_dir_fh_to_entry_byte
	jsr fs_dir_fh_to_entry_byte

	;* First cluster
fs_dir_entry_clust
	ldx #FH_FirstClust
	ldy	#FAT_FirstClust
	jsr fs_dir_fh_to_entry_byte	; Copy 2 bytes
	jsr fs_dir_fh_to_entry_byte

	;* Time and date
	ldx #FH_TimeDate
	ldy	#FAT_Createms
	jsr fs_dir_fh_to_entry_byte	; ms
	jsr fs_dir_fh_to_entry_byte ; time
	jsr fs_dir_fh_to_entry_byte
	jsr fs_dir_fh_to_entry_byte ; date
	jsr fs_dir_fh_to_entry_byte
	
	; Meta data - remember the parent directory
	ldx #0x03
fs_dir_fh_dirsect_byte
	lda fh_handle+FH_DirSect,x
	sta sd_sect,x
	dex
	bpl fs_dir_fh_dirsect_byte

	; Meta data - remember the offset in to the sd buffer, for writing back
	lda fh_handle+FH_DirOffset
	sta sd_slo
	lda fh_handle+FH_DirOffset+1
	sta sd_shi
	
	rts
	

;****************************************
;* fs_dir_fh_to_entry_byte
;* Copy fh_handle byte to fs_direntry area
;* Input 	: y = offset in directory entry
;*		 	: x = offset in handle entry
;* Output 	: None
;* Regs affected : All
;****************************************
fs_dir_fh_to_entry_byte
	lda fh_handle,x
	sta fs_direntry,y
	inx
	iny
	rts


;****************************************
;* fs_get_next_cluster
;* Given current cluster, find the next
;* Input : fh_handle
;* Output : 
;* Regs affected : None
;****************************************
fs_get_next_cluster
	; Get the FAT sector that current clust is in
	jsr fs_get_FAT_clust_sect

	; Get next from this cluster index need low byte only
	; as each FAT cluster contains 256 cluster entries
	ldy fh_handle+FH_CurrClust
	; X = Low byte, A = High byte of cluster
	jsr fs_getword_sd_buf

	; Calculate the sector address and make current cluster
	jsr fs_get_start_sect_data
	lda #0x20					; 32 sector per cluster countdown			
	sta fh_handle+FH_SectCounter

	rts
	
;****************************************
;* fs_IsEOF
;* End of File check (compare file pointer to file size)
;* Input : fh_handle
;* Output : C=1 if EOF
;* Regs affected : None
;****************************************
fs_isEOF
	ldx #0x03
fs_is_eof_cmp
	lda fh_handle+FH_Pointer,x
	cmp fh_handle+FH_Size,x
	bne fs_notEOF
	dex
	bpl fs_is_eof_cmp
fs_setEOF	
	sec							; C = 1 for EOF
	rts
fs_notEOF	
	clc							; C = 0 for not EOF
	rts


;* Wrapper than preserves A,X,Y
fs_isEOF_w
	pha
	phx
	phy
	
	jsr fs_isEOF

	ply
	plx
	pla
	rts
	
	
	
;****************************************
;* fs_inc_pointer
;* Increment file point, loading sectors and clusters as appropriate
;* This results in sd_buf containing the sector that the pointer points to
;* Input : fh_handle
;* Output : 
;* Regs affected : None
;****************************************
fs_inc_pointer
	;Increment pointer
	ldx #0x00
	ldy #0x04
	sec									; Always adds 1 first
fs_inc_pointer_byte
	lda fh_handle+FH_Pointer,x
	adc #0x00
	sta fh_handle+FH_Pointer,x
	inx
	dey
	bne fs_inc_pointer_byte

	lda fh_handle+FH_Pointer			; If low order == 0
	beq fs_inc_sector_ov				; Then sector 8 bits has overflowed
fs_inc_fin
	rts
fs_inc_sector_ov						; Check if sector bit 8 has overflowed
	lda fh_handle+FH_Pointer+1			; Load up next highest byte
	and #1								; If bit zero = 0 then must have
	bne fs_inc_fin						; overflowed.
	;Sector change required
	ldx #0x00
	ldy #0x04
	sec									; Always adds 1 first
fs_inc_fh_sect
	lda fh_handle+FH_CurrSec,x
	adc #0x00
	sta fh_handle+FH_CurrSec,x
	inx
	dey
	bne fs_inc_fh_sect
fs_inc_skip_sec_wrap
	dec fh_handle+FH_SectCounter		; If reached the end of a cluster
	bne fs_inc_load_sector				; Then get next cluster
	; Cluster change required
	jsr fs_get_next_cluster				; Get next cluster based on current	
fs_inc_load_sector
	jsr fs_isEOF						; Check not EOF
	bcs fs_skip_load_sect				; if so then don't load sector
	jsr fs_load_curr_sect				; Load the sector
fs_skip_load_sect
	rts


	
;****************************************
;* fs_get_byte
;* Get a byte and advance pointer
;* Input : fh_handle
;* Output : A = char, C = 1 (EOF or file not open)
;* Regs affected : None
;****************************************
fs_get_byte
	; First check that file is open to read
	lda #FS_FILEMODER
	and fh_handle+FH_FileMode
	beq fs_get_set_EOF

	jsr fs_isEOF						; If at EOF then error
	bcc fs_get_skip_EOF

fs_get_set_EOF
	lda #FS_ERR_EOF
	sta errno
	sec
	rts
fs_get_skip_EOF
	ldx fh_handle+FH_Pointer			; Low 8 bits of sector index
	ldy fh_handle+FH_Pointer+1			; Which half of sector?
	; A=SD buffer byte
	jsr fs_getbyte_sd_buf
	pha									; Remember the byte!
	jsr fs_inc_pointer					; Increment file pointers
	pla

	clc									; No error
	stz errno
	rts

;* Wrapper function that preserves X,Y (A=return value)
fs_get_byte_w
	phx
	phy

	jsr fs_get_byte
	
	ply
	plx
	rts

;****************************************
; With ASCII code in A, make upper
;****************************************
fs_to_upper
	cmp #'a'				; If >='a'
	bcc fs_to_upper_done
	cmp #'z'+1				; If <='z'
	bcs fs_to_upper_done
	sbc #0x1f				; Sub 0x1f+1 (C=0)
fs_to_upper_done
	rts
	

;****************************************
; Given the cluster #, find sector #
; Given clust in X,A
; Outputs to fh_handle->FH_CurrSec
;            fh_handle->FH_CurrClust
; Special case if X,A==0 then sector is
; the root sector
;****************************************
fs_get_start_sect_data
	stx fh_handle+FH_CurrClust
	stx fh_handle+FH_CurrSec+0
	sta fh_handle+FH_CurrClust+1
	sta fh_handle+FH_CurrSec+1
	
	; If cluster # == 0 then root directory
	ora fh_handle+FH_CurrSec+0
	beq fs_get_start_sect_root
	
	; Initialise to input sector
	stz fh_handle+FH_CurrSec+2
	stz fh_handle+FH_CurrSec+3
	
	; Sector = Cluster * 32
	; Shift left 5 times
	ldy #5
fs_get_data_sect_m5
	clc
	asl fh_handle+FH_CurrSec+0
	rol fh_handle+FH_CurrSec+1
	rol fh_handle+FH_CurrSec+2
	rol fh_handle+FH_CurrSec+3
	dey
	bne fs_get_data_sect_m5

	; Add data sector offset
	ldx #0x00
	ldy #0x04
	clc
fs_get_start_data
	lda fh_handle+FH_CurrSec,x
	adc fs_datasect,x
	sta fh_handle+FH_CurrSec,x
	inx
	dey
	bne fs_get_start_data
	rts
fs_get_start_sect_root
	ldx #3
fs_get_root_sect
	lda fs_rootsect,x
	sta fh_handle+FH_CurrSec,x
	dex
	bpl fs_get_root_sect
	rts

	
;****************************************
; Load the current sector in FH
;****************************************
fs_load_curr_sect
	pha
	phx

	ldx #0x03
fs_load_cpy_sect
	lda fh_handle+FH_CurrSec,x
	sta sd_sect,x
	dex
	bpl fs_load_cpy_sect
	lda #hi(sd_buf)
	jsr sd_sendcmd17

	plx
	pla
	rts

;****************************************
; Flush the current sector
;****************************************
fs_flush_curr_sect
	pha
	phx

	ldx #0x03
fs_flush_cpy_sect
	lda fh_handle+FH_CurrSec,x
	sta sd_sect,x
	dex
	bpl fs_flush_cpy_sect
	lda #hi(sd_buf)				; Sending data in sd_buf
	jsr sd_sendcmd24
	
	plx
	pla
	rts


;****************************************
;* fs_find_empty_clust
;* Find an empty cluster to write to
;* Input : None
;* Output : fh_handle->FH_CurrClust is the empty cluster
;* Regs affected : None
;****************************************
fs_find_empty_clust
	; Starting at cluster 0x0002
	lda #02
	sta fh_handle+FH_CurrClust
	stz fh_handle+FH_CurrClust+1

	; Start at the first FAT sector
	ldx #0x03
fs_find_init_fat
	lda fs_fatsect,x
	sta fh_handle+FH_CurrSec,x
	dex
	bpl fs_find_init_fat

	; There is only enough room for 512/2 = 256 cluster entries per sector
	; There are 256 sectors of FAT entries

fs_check_empty_sector
	jsr fs_load_curr_sect			; Load a FAT sector
fs_check_curr_clust
	ldy fh_handle+FH_CurrClust		; Index in to this FAT sector
	jsr fs_getword_sd_buf
	cpx #0
	bne fs_next_fat_entry
	cmp #0
	bne fs_next_fat_entry
	
	; If got here then empty cluster found
	; fh_handle->FH_CurrClust is the empty cluster
	
	; Mark this cluster as used
	ldx #0xff
	lda #0xff
	jsr fs_putword_sd_buf

	; flush this FAT entry back so this cluster is safe from reuse
	jsr fs_flush_curr_sect
	
	stz fh_handle+FH_SectCounter	; Zero the sector count
	ldx fh_handle+FH_CurrClust
	lda fh_handle+FH_CurrClust+1
	jsr fs_get_start_sect_data		; Initialise the sector
	rts
	; If got here then need to find another cluster
fs_next_fat_entry
	_incZPWord fh_handle+FH_CurrClust	; Increment the cluster number
	; Only 256 FAT entries in a sector of 512 bytes
	lda fh_handle+FH_CurrClust		; Check low byte of cluster number
	bne fs_check_curr_clust			; Else keep checking clusters in this sector
	; Every 256 FAT entries, need to get a new FAT sector
fs_next_fat_sect
	jsr fs_inc_curr_sec				; Increment to the next FAT sector
	bra fs_check_empty_sector		; Go an load the new FAT sector and continue
	

;****************************************
;* fs_inc_curr_sec
;* Increment sector by 1
;* Input : fh_handle has the sector
;****************************************
fs_inc_curr_sec
	; add 1 to LSB as sector address is little endian
	ldx #0x00
	ldy #0x04
	sec
fs_inc_sec_byte
	lda fh_handle+FH_CurrSec,x
	adc #0x00
	sta fh_handle+FH_CurrSec,x
	inx
	dey
	bne fs_inc_sec_byte

	rts
	

;****************************************
;* fs_get_FAT_clust_sect
;* Given FH_CurrClust, set FH_CurrSec so that
;* the sector contains the FAT entry
;* Input : fh_handle has the details
;* Output : None
;* Regs affected : None
;****************************************
fs_get_FAT_clust_sect
	; Sector offset in to FAT = high byte
	; because a sector can hold 256 FAT entries
	lda fh_handle+FH_CurrClust+1
	sta fh_handle+FH_CurrSec
	stz fh_handle+FH_CurrSec+1
	stz fh_handle+FH_CurrSec+2
	stz fh_handle+FH_CurrSec+3
	
	; Add the FAT offset
	clc
	ldx #0x00
	ldy #0x04
fs_get_add_fat
	lda fh_handle+FH_CurrSec,x
	adc fs_fatsect,x
	sta fh_handle+FH_CurrSec,x
	inx
	dey
	bne fs_get_add_fat

	; Now load the sector containing this cluster entry
	jsr fs_load_curr_sect

	rts

	
;****************************************
;* fs_update_FAT_entry
;* FH_LastClust updated with FH_CurrClust
;* Input : fh_handle has the details
;* Output : None
;* Regs affected : None
;****************************************
fs_update_FAT_entry
	pha
	phx
	phy
	
	lda fh_handle+FH_CurrClust+0	; Save current cluster lo byte
	pha
	lda fh_handle+FH_CurrClust+1	; Save current cluster hi byte
	pha
	; Move back to the last cluster entry
	_cpyZPWord fh_handle+FH_LastClust,fh_handle+FH_CurrClust

	jsr fs_get_FAT_clust_sect		; Get the FAT sector to update
	; Index in to the FAT sector
	ldy fh_handle+FH_LastClust
	; Get current cluster hi,lo from stack
	pla
	plx
	stx fh_handle+FH_CurrClust		; Make it the current cluster again
	sta fh_handle+FH_CurrClust+1	; Make it the current cluster again

	; Update FAT entry Y with current cluster X,A
	jsr fs_putword_sd_buf

	; The appropriate FAT sector has been updated
	; Now flush that sector back	
	jsr fs_flush_curr_sect
	
	ply
	plx
	pla
	rts
	

;****************************************
;* fs_put_byte
;* Put out a byte, incrementing size
;* and committing clusters as necessary
;* including reflecting this in the FAT table
;* Input : fh_handle has the details, A = Byte to write
;* Output : None
;* Regs affected : None
;****************************************
fs_put_byte
	pha			; Save A until needed later
	; First check that file is open to write
	lda #FS_FILEMODEW
	and fh_handle+FH_FileMode
	bne fs_put_skip_err
	; C=1 means error
	pla
	sec
	rts
fs_put_skip_err
	; Before writing a byte, need to check if the current
	; sector is full.
	; Check low 9 bits of size and if zero size (i.e. 1st byte being put)
	lda fh_handle+FH_Size
	bne fs_put_do_put
	lda fh_handle+FH_Size+1
	beq fs_put_do_put
	and #1
	bne fs_put_do_put
	; Got here then current sector is full
	; We need to flush this sector to disk
	jsr fs_flush_curr_sect
	; Move to next sector in the cluster
	jsr fs_inc_curr_sec
	; Bump the sector counter
	inc fh_handle+FH_SectCounter
	; Check if counter at sectors per cluster limit
	lda fh_handle+FH_SectCounter
	cmp #0x20
	bne fs_put_do_put
	; We need to find a new cluster now
	; But first update the FAT chain
	; so that the last cluster points to this
	jsr fs_update_FAT_entry
	; Before finding a new cluster
	; make the current the last
	_cpyZPWord fh_handle+FH_CurrClust,fh_handle+FH_LastClust
	; Go find a new empty clust
	; starts at sector 0
	jsr fs_find_empty_clust
	; Finally, can write a byte to the
	; SD buffer in memory
fs_put_do_put	
	ldx fh_handle+FH_Size			; Load size low as index in to buffer
	ldy fh_handle+FH_Size+1			; Check which half
	pla								; Get A off stack
	jsr fs_putbyte_sd_buf
fs_put_inc_size
	sec
	ldx #0x00
	ldy #0x04
fs_put_inc_size_byte
	lda fh_handle+FH_Size,x
	adc #0
	sta fh_handle+FH_Size,x
	inx
	dey
	bne fs_put_inc_size_byte
fs_put_fin
	clc
	rts


;* Wrapper function to save A,X,Y
fs_put_byte_w
	phx
	phy
	pha

	jsr fs_put_byte
	
	pla
	ply
	plx
	rts

;****************************************
;* fs_dir_save_entry
;* Save dir entry back to disk
;* Input : fh_handle has all the details
;* Output : None
;* Regs affected : None
;****************************************
fs_dir_save_entry
	; Retrieve the sector where the file entry goes
	ldx #0x03
fs_dir_curr_sect
	lda fh_handle+FH_DirSect,x
	sta fh_handle+FH_CurrSec,x
	dex
	bpl fs_dir_curr_sect
	
	jsr fs_load_curr_sect

	; Restore index in to the correct entry
	lda fh_handle+FH_DirOffset
	sta sd_slo
	lda fh_handle+FH_DirOffset+1
	sta sd_shi
	
	; Copy FAT file desc cache to sd position
	ldy #FATFileDesc-1			; Cache the fs_direntry sd_lo,hi
fs_dir_copy_entry_sd_byte
	lda fs_direntry,y
	sta (sd_slo),y
	dey
	bpl fs_dir_copy_entry_sd_byte
	
	; Now flush this back to disk
	
	jsr fs_flush_curr_sect
	
	; Phew we are done
	rts


;****************************************
;* fs_find_named
;* Find named file in current directory
;* Input : fh_handle has the name
;* Output : None
;* Regs affected : None
;****************************************
fs_find_named
	clc							; Find active file
	jsr fs_dir_find_entry		; Find entry from current position
	bcs	fs_name_not_found		; If C then no more entries
	ldy #0						; Index to filespec
	ldx #0						; Index to filename
fs_find_check_name
	lda (fh_handle+FH_FSpecPtr),y	; File spec char
	jsr fs_to_upper					; Case insensitive
	cmp fh_handle,x					; compare with this filehandle
	bne fs_find_next
	cmp #0						; If no more bytes in name to check
	beq fs_name_found
	inx
	iny
	bra fs_find_check_name
fs_find_next
	jsr fs_dir_next_entry		; Get next entry to check
	bra fs_find_named
fs_name_found
	clc							; C=0 file found
	rts
fs_name_not_found				; If C already set then not found
	sec
	rts

	
;****************************************
;* fs_open_read
;* Open a file for reading
;* Input : fh_handle has the name
;* Output : None
;* Regs affected : None
;****************************************
fs_open_read
	jsr fs_dir_root_start		; Start at root of current directory
	jsr fs_find_named			; Try to find the file
	bcs fs_open_not_found		; C=1 not found
fs_open_found
	lda #0x20					; 32 sector per cluster countdown			
	sta fh_handle+FH_SectCounter

	ldx fh_handle+FH_FirstClust	; Load up first cluster
	lda fh_handle+FH_FirstClust+1

	jsr fs_get_start_sect_data	; Calc the first sector
	jsr fs_load_curr_sect		; Load it in to sd_buf


	ldx #0x03					; Initialise pointer to beginning
fs_open_init_pointer
	stz fh_handle+FH_Pointer,x
	dex
	bpl fs_open_init_pointer

	; Set file mode to read
	lda #FS_FILEMODER
	sta fh_handle+FH_FileMode

	clc
fs_open_not_found
	rts

;* Wrapper function that saves A,X,Y *
;* X,A = file spec ptr
fs_open_read_w
	pha
	phx
	phy

	; Save file name pointer
	stx fh_handle+FH_FSpecPtr
	sta fh_handle+FH_FSpecPtr+1
	jsr fs_open_read
	
	ply
	plx
	pla
	rts


;****************************************
;* fs_stamptimedate
;* Stamp date and time to fhandle
;* Input : None (reads RTC)
;* Output : None
;* Regs affected : all
;****************************************
fs_stamptimedate
	; Point to temp space
	ldx #lo(fs_scratch)
	lda #hi(fs_scratch)
	; Get the current time and date - 6 bytes
	jsr _rtc_gettimedate
	; Now convert from hhmmssddmmyy format to FAT16
	; Byte bit and byte order as follows
	; byte 0 = milliseconds
	; byte 1 = mmmsssss
	; byte 2 = hhhhhmmm
	; byte 3 = MMMDDDDD
	; byte 4 = YYYYYYYM
	; First decide on milliseconds
	ldx #0								; Assume 0 milliseconds
	lda fs_scratch+2					; Seconds
	and #1
	bne fs_stamptimedate_ms
	ldx #100							; 10x100 milliseconds = 1 second
fs_stamptimedate_ms
	stx fh_handle+FH_TimeDate			; Save milliseconds
	
	lda fs_scratch+0					; Get hours
	asl a								; Move to top 5 bits
	asl a
	asl a
	sta fh_handle+FH_TimeDate+2			; Put in time field byte 1

	lda fs_scratch+1					; Get minutes
	lsr a								; Put top 3 bits in to LSB
	lsr a
	lsr a
	ora fh_handle+FH_TimeDate+2			; Combine with hours
	sta fh_handle+FH_TimeDate+2			; Put in time field byte 1

	lda fs_scratch+1					; Get minutes
	asl a								; Get bottom 3 bits of mins to top 3 bits of time field (low)
	asl a
	asl a
	asl a
	asl a
	sta fh_handle+FH_TimeDate+1			; Save in time field byte 2
	
	lda fs_scratch+2					; Get seconds again
	lsr a								; Divide by 2
	ora fh_handle+FH_TimeDate+1			; Combine with time field byte 2
	sta fh_handle+FH_TimeDate+1			; Save back to time field (high)
	
	lda fs_scratch+5					; Get year
	clc									; Add 20 to get offset from 1980
	adc #20
	asl a								; Shift up
	sta fh_handle+FH_TimeDate+4			; Put in date field byte 1

	lda fs_scratch+4					; Get months
	lsr a								; Bit 3 in to bit 0
	lsr a
	lsr a
	ora fh_handle+FH_TimeDate+4			; Combine with date field byte 1
	sta fh_handle+FH_TimeDate+4			; Put in date field byte 1

	lda fs_scratch+4					; Get months
	asl a								; 3 LSBs in to MSB of A (discard MSB)
	asl a
	asl a
	asl a
	asl a
	ora fs_scratch+3					; Combine with day
	sta fh_handle+FH_TimeDate+3			; And save in date field byte 2

	rts
	
;****************************************
;* fs_unpack_string
;* Open a file for reading
;* Input : X,A points to 4 bytes of time/date in FAT16 format
;* Output : None
;* Regs affected : None
;****************************************
fs_unpack_string


;****************************************
;* fs_create_filedir
;* Create a file or directory
;* Input : fh_handle has the name and type attribute
;*		 : new file / directory will be created.
;*		 : Careful to check filename is *unique*
;*		 : before calling this routine.
;*		 : File will be in write mode, needs to be
;*		 : closed to be properly saved
;*		 : C=0 means file, C=1 meand directory
;* Output : None
;* Regs affected : None
;****************************************
fs_create_filedir
	pha
	phx
	phy
	php							; Save file or dir request for later

	jsr fs_dir_root_start		; Start at root of current directory
	sec							; Find an empty file entry
	jsr fs_dir_find_entry		; Find a valid entry
	bcs	fs_create_fd_err		; Error, didn't find!

	lda #0						; Assume creating file
	plp							; Unless C=1
	bcc fh_create_skip_dir
	; Set attribute for directory
	lda #FAT_Attr_Dir
fh_create_skip_dir
	sta fh_handle+FH_Attr

	; Copy filespec to file handle
	ldy #0
	ldx #FH_Name
fs_create_copy_fspec
	lda (fh_handle+FH_FSpecPtr),y
	sta fh_handle,x
	beq fs_create_copy_fspec_done
	inx
	iny
	bra fs_create_copy_fspec

fs_create_copy_fspec_done
	stz fh_handle+FH_Size+0		; Size is zero
	stz fh_handle+FH_Size+1
	stz fh_handle+FH_Size+2
	stz fh_handle+FH_Size+3

	jsr fs_stamptimedate		; Put date time stamp in to fh_fhandle
	
	jsr fs_find_empty_clust		; Find + record its first cluster
	
	; Set current, last and first cluster to the same
	lda fh_handle+FH_CurrClust
	sta fh_handle+FH_FirstClust
	sta fh_handle+FH_LastClust
	lda fh_handle+FH_CurrClust+1
	sta fh_handle+FH_FirstClust+1
	sta fh_handle+FH_LastClust+1

	; Set file mode to write
	lda #FS_FILEMODEW
	sta fh_handle+FH_FileMode

	clc
fs_create_fd_err
	ply
	plx
	pla
	rts


;****************************************
;* fs_create_dirptr
;* Create a file that is a pointer to a directory
;* Input : fh_handle has the name and type attribute
;*		 : Entry will be created pointing tp the
;*		 : cluster in FH_CurrClust.
;*		 : Careful to check filename is *unique*
;*		 : before calling this routine.
;*		 : File will be in write mode, needs to be
;*		 : closed to be properly saved
;* Output : None
;* Regs affected : None
;****************************************
fs_create_dirptr
	lda #FAT_Attr_Dir
	sta fh_handle+FH_Attr		; Make it a directory

	stz fh_handle+FH_Size+0		; Size is zero
	stz fh_handle+FH_Size+1
	stz fh_handle+FH_Size+2
	stz fh_handle+FH_Size+3

	clc
	rts


;****************************************
;* fs_open_write
;* Open a file for writing
;* Input : fh_handle has the name
;*		 : existing file will overwritten
;*		 : new file will be created
;* Output : None
;* Regs affected : None
;****************************************
fs_open_write
	; try and delete any file with the same name first
	jsr fs_delete
	clc
	jsr fs_create_filedir		; Ok go create this file now

	rts

;* Wrapper function that saves A,X,Y *
fs_open_write_w
	pha
	phx
	phy

	stx fh_handle+FH_FSpecPtr
	sta fh_handle+FH_FSpecPtr+1
	jsr fs_open_write
	
	ply
	plx
	pla
	rts


;****************************************
;* fs_close_filedir
;* Close a file/dir, important for new files
;* Input : fh_handle details
;* Output : None
;* Regs affected : None
;****************************************
fs_close_filedir
	; Only need to close down stuff in write mode
	lda fh_handle+FH_FileMode
	; Zero out file mode
	stz fh_handle+FH_FileMode
	; If filemode N bit clear then done
	bpl fs_close_done
		
	; Flush the current sector
	jsr fs_flush_curr_sect

	; Update the chain from the last cluster
	jsr fs_update_FAT_entry

	; Make current sector = last
	lda fh_handle+FH_CurrClust
	sta fh_handle+FH_LastClust
	lda fh_handle+FH_CurrClust+1
	sta fh_handle+FH_LastClust+1
	; Need to update the FAT entry
	; to show this cluster is last
	lda #0xff
	sta fh_handle+FH_CurrClust
	sta fh_handle+FH_CurrClust+1
	; Now update the FAT entry to mark the last cluster
	jsr fs_update_FAT_entry
	; Then finally save the directory entry
	; First fhandle to FATFileDesc
	jsr fs_dir_fhandle_to_entry

	; Update modified date and time to be same as created
	lda fs_direntry+FAT_CreateDate
	sta fs_direntry+FAT_ModDate
	sta fs_direntry+FAT_AccessDate
	lda fs_direntry+FAT_CreateDate+1
	sta fs_direntry+FAT_ModDate+1
	sta fs_direntry+FAT_AccessDate+1
	lda fs_direntry+FAT_CreateTime
	sta fs_direntry+FAT_ModTime
	lda fs_direntry+FAT_CreateTime+1
	sta fs_direntry+FAT_ModTime+1
	
	jsr fs_dir_save_entry

fs_close_done
	rts


;* Wrapper function preserving A,X,Y *
fs_close_w
	pha
	phx
	phy
	
	jsr fs_close_filedir
	
	ply
	plx
	pla
	rts
	
	


;****************************************
;* fs_delete
;* Delete a file
;* Input : fh_handle has the name
;* Output : None
;* Regs affected : None
;****************************************
fs_delete
	jsr fs_open_read			; Try and open the file
	bcs fs_delete_fin			; If not found then fin
	
	; Mark first char with deleted indicator
	lda #0xe5
	sta fh_handle+FH_Name

	; Save this back to directory table
	; First fhandle to FATFileDesc
	jsr fs_dir_fhandle_to_entry	
	jsr fs_dir_save_entry

	; Now mark all related clusters as free
	ldx fh_handle+FH_FirstClust
	stx fh_handle+FH_CurrClust
	ldy fh_handle+FH_FirstClust+1
	sty fh_handle+FH_CurrClust+1
fs_delete_clust
	; X and Y always contain current cluster
	; Make last = current
	stx fh_handle+FH_LastClust
	sty fh_handle+FH_LastClust+1

	; Given current cluster, find next
	; save in X,Y
	jsr fs_get_next_cluster
	; load X,Y with the next cluster
	ldx fh_handle+FH_CurrClust
	ldy fh_handle+FH_CurrClust+1
	
	; Zero out the cluster number
	stz fh_handle+FH_CurrClust
	stz fh_handle+FH_CurrClust+1

	; Update FAT entry of Last Cluster with zero
	jsr fs_update_FAT_entry

	; Restore the next cluster found earlier
	stx fh_handle+FH_CurrClust
	sty fh_handle+FH_CurrClust+1

	; If the next cluster is not 0xffff
	; then continue
	cpx #0xff
	bne fs_delete_clust
	cpy #0xff
	bne fs_delete_clust
	clc
fs_delete_fin
	rts

;** Wrapper function which saves A,X,Y **
fs_delete_w
	pha
	phx
	phy

	stx fh_handle+FH_FSpecPtr
	sta fh_handle+FH_FSpecPtr+1
	jsr fs_delete
	
	ply
	plx
	pla
	rts
	
;****************************************
;* fs_chdir_direct
;* Change root directory directly using cluster
;* Input : FH_FirstClust has cluster number of dir
;* Output : None
;* Regs affected : None
;****************************************
fs_chdir_direct
	; Calculate sector from this directory cluster
	ldx fh_handle+FH_FirstClust
	lda fh_handle+FH_FirstClust+1
	
	; Also record the directory cluster #
	stx fs_dirclust
	sta fs_dirclust+1
	
	jsr fs_get_start_sect_data	; Calc the first sector of dir
	
	ldx #3						; Copy sector to dirsect
fs_chdir_direct_sect
	lda fh_handle+FH_CurrSec,x
	sta fs_dirsect,x
	dex
	bpl fs_chdir_direct_sect
	rts
	

;****************************************
;* fs_chdir
;* Change root directory
;* Input : fh_handle has the name
;* Output : None
;* Regs affected : None
;****************************************
fs_chdir
	lda (fh_handle+FH_FSpecPtr)	; First byte of name != 0?
	bne fs_chdir_find			; Then find the file
	sta fh_handle+FH_FirstClust	; Else use zero to indicate root
	sta fh_handle+FH_FirstClust+1
	beq fs_chdir_go				; To go to the root directory

fs_chdir_find
	jsr fs_dir_root_start		; Start at root of current directory
	jsr fs_find_named			; Try to find the file
	bcs fs_chdir_not_found		; C=1 not found

fs_chdir_go
	; Use populated cluster number to go directly
	jsr fs_chdir_direct

fs_chdir_fin
	clc
fs_chdir_not_found
	rts

;** Wrapper function which saves A,X,Y **
fs_chdir_w
	pha
	phx
	phy
	
	stx fh_handle+FH_FSpecPtr
	sta fh_handle+FH_FSpecPtr+1
	jsr fs_chdir
	
	ply
	plx
	pla
	rts

;****************************************
;* fs_mkdir
;* Create a file
;* Input : fh_handle has the name
;*		 : checks if file already exists
;*		 : new directory will be created
;*       : including . and .. entries
;* Output : None
;* Regs affected : None
;****************************************
fs_mkdir
	jsr fs_dir_root_start		; Start at root of current directory

	; If file or directory with same name exists, then not allowed
	jsr fs_find_named			; Try to find the file
	bcs fs_mkdir_ok				; C=1 then no file found - ok to continue

	sec							; Indicate fail
	rts

fs_mkdir_ok	
	; Remember parent directory ".." cluster #
	lda fs_dirclust
	pha
	lda fs_dirclust+1
	pha

	sec
	jsr fs_create_filedir		; Go create the directory entry
	jsr fs_close_filedir		; Commit
	
	; Remember this directory "." cluster #
	lda fh_handle+FH_FirstClust
	pha
	lda fh_handle+FH_FirstClust+1
	pha
	
	; Need to zero the directory cluster
	; First create a zero filled buffer 512 bytes
	lda #0
	tax
	ldy #0
fs_mkdir_zero_sector
	jsr fs_putbyte_sd_buf
	dex 
	bne fs_mkdir_zero_sector
	iny
	cpy #2
	bne fs_mkdir_zero_sector
	; Now fill a cluster's worth of sectors with zero buffer
	; Cluster = 16k, buffer = 512 bytes => 32 sectors
	
	; Get directory cluster # in to X,A and calculate sector #
	ldx fh_handle+FH_FirstClust
	lda fh_handle+FH_FirstClust+1
	jsr fs_get_start_sect_data
	
	; Now write cluster worth of sectors
	ldx #32
fs_mkdir_zero_cluster
	phx
	jsr fs_flush_curr_sect
	jsr fs_inc_curr_sec
	plx
	dex
	bne fs_mkdir_zero_cluster
	
	; Goto newly created directory (it's empty)
	; Use cluster number
	jsr fs_chdir
	jsr fs_dir_root_start		; Start at root of current directory (loads the sector)
	; Go and find first available slot in directory C=1
	sec
	jsr fs_dir_find_entry
	; Restore current directory cluster - it's reverse order on stack
	pla
	sta fh_handle+FH_FirstClust+1
	pla
	sta fh_handle+FH_FirstClust
	jsr fs_create_dirptr		; Go create the '.' file entry
	; Create name for entry "."
	lda #'.'
	sta fh_handle+0
	stz fh_handle+1
	; Convert fhandle to FATFileDesc
	jsr fs_dir_fhandle_to_entry	
	jsr fs_dir_save_entry		; Save it to to the directory cluster

	; Go and find next available slot in directory C=1
	jsr fs_dir_next_entry
	sec
	jsr fs_dir_find_entry
	; Restore parent directory cluster - it's reverse order on stack
	pla
	sta fh_handle+FH_FirstClust+1
	pla
	sta fh_handle+FH_FirstClust
	jsr fs_create_dirptr		; Go create the '..' file entry
	; Create name for entry ".."
	lda #'.'
	sta fh_handle+0
	sta fh_handle+1
	stz fh_handle+2
	; Convert fhandle to FATFileDesc
	jsr fs_dir_fhandle_to_entry	
	jsr fs_dir_save_entry		; Save it to to the directory cluster

	; FH_FirstClust points to parent - go to it
	jsr fs_chdir_direct
	
	clc							; Indicate success

fs_mkdir_fin
	rts

;** Wrapper function which saves A,X,Y **
fs_mkdir_w
	pha
	phx
	phy
	
	stx fh_handle+FH_FSpecPtr
	sta fh_handle+FH_FSpecPtr+1
	jsr fs_mkdir

	ply
	plx
	pla
	rts

;****************************************
;* fs_dir_fhandle_to_str
;* Unpack contents of fhandle to a string 
;* Input : fs_fhandle, A,X=pointer to string
;* Output : 43 bytes of string (inc, zero pointer)
;* Column	Len	Offset	Desc
;*	name	12	0 		8.3 space padded to right
;*	type	3	13		DIR if directory else FIL
;*	date	8	19		DD/MM/YY
;*	time	8	28		hh/mm/ss
;*	size	5	37		right justified no leading zeros
;* Regs affected : None
;****************************************
fs_dir_str
	db "DIR"
fs_dir_fil
	db "   "
fs_dir_fhandle_str
	stx tmp_v1
	sta tmp_v1+1
	; Put zero terminator at pos 41
	ldy #40
	lda #0
	sta (tmp_v1),y
	; Pre-fill with spaces
	dey
	lda #' '
fs_dir_fhandle_pad_spc
	sta (tmp_v1),y
	dey
	bpl fs_dir_fhandle_pad_spc
	; Put '/' separator for date
	lda #'/'
	ldy #19
	sta (tmp_v1),y
	ldy #22
	sta (tmp_v1),y
	; Put ':' separator for time
	lda #':'
	ldy #28
	sta (tmp_v1),y
	ldy #31
	sta (tmp_v1),y
	;* Unpack name - copy 8.3 (12 chars) until zero
	ldx #FH_Name				; Source
	ldy #0						; Name offset
fs_dir_fhandle_name
	lda fh_handle,x				; Get name char
	beq	fs_dir_fhandle_dotype	; Process attribute if end of string
	jsr fs_to_upper				; Case insensitive
	sta (tmp_v1),y
	inx
	iny
	cpy #12
	bne fs_dir_fhandle_name		; Max 12 chars for a filename
fs_dir_fhandle_dotype
	lda fh_handle+FH_Attr		; Check the type
	ldy #13						; Point to column for type
	ldx #0						; Point to DIR string
	cmp #FAT_Attr_Dir			; Directory?
	beq fs_dir_fhandle_type
	ldx #3						; Point to FIL string
fs_dir_fhandle_type				; copy 3 chars
	lda fs_dir_str,x
	sta (tmp_v1),y
	inx
	iny
	cpy #16
	bne fs_dir_fhandle_type

	;* Date
	; Extract year
	lda fh_handle+FH_TimeDate+4 ; Top 7 bits is year
	lsr a
	sec							; Remove offset from 1980 (-20)
	sbc #20
	ldy #23						; Save to date field
	jsr fs_util_num_bcd			; Put digits
	; Extract month
	lda fh_handle+FH_TimeDate+4 ; Bottom bit is bit 3 of month
	lsr a						; Put in to C
	lda fh_handle+FH_TimeDate+3	; Top 3 bits are month
	ror a						; Rotate in C for bit 3 (now have 4 bits)
	lsr a						; Bring to low nibble
	lsr a
	lsr a
	lsr a
	ldy #20						; Month field position
	jsr fs_util_num_bcd			; Put digits
	; Extract days
	lda fh_handle+FH_TimeDate+3 ; Bottom bottom 5 bits are what we need
	and #0x1f					; So mask that
	ldy #17						; Day field position
	jsr fs_util_num_bcd			; Put digits

	;* Time
	; Extract hours
	lda fh_handle+FH_TimeDate+2	; Ignore ms. Top5 bits is hours
	lsr a
	lsr a
	lsr a
	ldy #26						; Hours field
	jsr fs_util_num_bcd			; Put digits
	; Extract minutes
	lda fh_handle+FH_TimeDate+1	; Top 3 bits is bit 0,1,2 of minutes
	lsr a						; Shift it to bottom
	lsr a
	lsr a
	lsr a
	lsr a
	sta fs_scratch				; Save partial result
	lda fh_handle+FH_TimeDate+2	; Bottom 3 bits is bit 3,4,5 of minutes
	and #0x07					; Mask for those bits
	asl a						; Shift up in to position 3,4,5
	asl a
	asl a
	ora fs_scratch				; Combine with top 3 bits
	ldy #29						; Minutes field
	jsr fs_util_num_bcd			; Put digits
	; Extract seconds
	lda fh_handle+FH_TimeDate+1	; Bottom 5 bits is seconds / 2
	and #0x1f					; Mask for those
	asl a						; x2
	ldy #32						; Seconds field
	jsr fs_util_num_bcd			; Put digits
	; Extract size
	lda fh_handle+FH_Size+1		; Only taking 16 bits of size A=High
	ldx fh_handle+FH_Size+0		; X=Low
	jsr word_to_bcd				; X,A to BCD in num_a (3 bytes)
	lda num_a+2					; 100k and 10k digits
	ldy #35						; Position of size field
	jsr fs_util_num_bcd_a		; Put only 10k digit
	lda num_a+1					; 1k and hundreds digits
	jsr fs_util_num_bcd_xa		; Put digits in AX
	lda num_a+0					; tens and units digits
	jsr fs_util_num_bcd_xa		; Put digits in AX
	ldy #35						; Check for leading zeros
fs_dir_fhandle_zeros
	lda (tmp_v1),y
	cmp #'0'
	bne fs_dir_fhandle_done
	lda #' '
	sta (tmp_v1),y
fs_dir_fhandle_zskip
	iny
	cpy #39						; Last zero can stay
	bne fs_dir_fhandle_zeros
	; byte 0 = milliseconds
	; byte 1 = mmmsssss
	; byte 2 = hhhhhmmm
	; byte 3 = MMMDDDDD
	; byte 4 = YYYYYYYM
fs_dir_fhandle_done
	rts

fs_util_num_bcd
	tax							; Only can do 00-99
	lda #0						; So high byte = 0
	jsr word_to_bcd				; X,A to BCD in num_a
	lda num_a+0					; Two least significant BCD digits (00-99)
fs_util_num_bcd_xa				; Enter here if bcd conversion done, A=BCD number
	pha
	tax							; X contains this
	pla							; Two least significant BCD digits (00-99)
	lsr a						; Get tens digit 
	lsr a
	lsr a
	lsr a
	clc
	adc #'0'					; Convert to ascii
	sta (tmp_v1),y				; Save in string position (2 chars)
	iny
	txa
fs_util_num_bcd_a				; Enter here if only units needed in A
	and #0x0f					; Get units digit
	clc
	adc #'0'					; Convert to ascii
	sta (tmp_v1),y
	iny
	rts


	
msg_initialising_fs
	db "Mounting filesystem\r\r",0
msg_noinit_fs
	db "No filesystem available\r\r",0
mod_sz_sd_fs_e
