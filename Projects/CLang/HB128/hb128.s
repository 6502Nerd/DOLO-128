.include "hb128.inc"

.export  _dfcl_mode, _dfcl_colour, _dfcl_line, _dfcl_circle, _dfcl_box
.export _dfcl_plot, _dfcl_cls, _dfcl_scrn, _dfcl_gotoxy
.export _dfcl_ptinit, _dfcl_ptload, _dfcl_ptrun, _dfcl_ptstop
.export _dfcl_sprpat, _dfcl_sprcol, _dfcl_sprpos, _dfcl_sprnme
.export _dfcl_chdir, _dfcl_bload, _dfcl_vload, _dfcl_font

.import         popa, popax, popptr1, pushax
.importzp       ptr1, ptr2, ptr3

.segment  "CODE"

__switch_bank0:
    pha
    ; Switch to new bank
    lda _dfcl1_IO_0+_dfcl1_PRB
    and #%00111111
    ora #%11000000          ; 11 = bank 0
    sta _dfcl1_IO_0+_dfcl1_PRB
    pla
    rts

__switch_bank1:
    pha
    ; Switch to new bank
    lda _dfcl1_IO_0+_dfcl1_PRB
    and #%00111111
    ora #%10000000          ; 10 = bank 1
    sta _dfcl1_IO_0+_dfcl1_PRB
    pla
    rts

__switch_bank2:
    pha
    ; Switch to new bank
    lda _dfcl1_IO_0+_dfcl1_PRB
    and #%00111111
    ora #%01000000          ; 01 = bank 2
    sta _dfcl1_IO_0+_dfcl1_PRB
    pla
    rts

__switch_bank3:
    pha
    ; Switch to new bank
    lda _dfcl1_IO_0+_dfcl1_PRB
    and #%00111111          ; 00 = bank 3
    sta _dfcl1_IO_0+_dfcl1_PRB
    pla
    rts

; void dfcl_mode(unsigned char mode);
_dfcl_mode:
    jsr __switch_bank0
    jmp _dfcl0_gr_init_screen

; void dfcl_colour(unsigned char reg, unsigned char fg, unsigned char bg);
_dfcl_colour:
    sta _dfcl0_df_tmpptrc
    jsr popa
    sta _dfcl0_df_tmpptrb
    jsr popa
    sta _dfcl0_df_tmpptra

    jsr __switch_bank1
    jmp _dfcl1_dfcl_colour

; void dfcl_circle(unsigned char x, unsigned char y, unsigned char r);
_dfcl_circle:
    sta _dfcl1_num_a+2
    jsr popa
    sta _dfcl1_num_a+1
    jsr popa
    sta _dfcl1_num_a
    jsr __switch_bank0
    jmp _dfcl0_gr_circle

; dfcl_line(unsigned char x1, unsigned char y1, unsigned char x2, unsigned char y2);
_dfcl_line:
    sta _dfcl1_num_a+3
    jsr popa
    sta _dfcl1_num_a+2
    jsr popa
    sta _dfcl1_num_a+1
    jsr popa
    sta _dfcl1_num_a
    jsr __switch_bank0
    jmp _dfcl0_gr_line

; void dfcl_box(unsigned char x1, unsigned char y1, unsigned char x2, unsigned char y2);
_dfcl_box:
    sta _dfcl1_num_a+3
    jsr popa
    sta _dfcl1_num_a+2
    jsr popa
    sta _dfcl1_num_a+1
    jsr popa
    sta _dfcl1_num_a
    jsr __switch_bank0
    jmp _dfcl0_gr_box

; void dfcl_cls();
_dfcl_cls:
    jsr __switch_bank0
    jmp _dfcl0_gr_cls

; void dfcl_plot(unsigned char x, unsigned char y, unsigned char c);
_dfcl_plot:
    pha
    jsr popa
    pha
    jsr popa
    tax
    ply
    pla
    jsr __switch_bank0
    jmp _dfcl0_gr_plot

; unsigned char dfcl_scrn(unsigned char x, unsigned char y);
_dfcl_scrn:
    pha
    jsr popa
    tax
    ply
    jsr __switch_bank0
    jsr _dfcl0_gr_get
    ldx #0              ; Ensure high byte is zero
    rts

; void dfcl_gotoxy(unsigned char x, unsigned char y);
_dfcl_gotoxy:
    pha
    jsr popa
    tax
    ply
    jsr __switch_bank0
    jsr _dfcl0_gr_set_cur
    rts


; ** Sound and PT3 **
; void dfcl_ptinit(unsigned char *ptr,unsigned char loop);
_dfcl_ptinit:
    pha                     ; Save loop pref for later
    jsr popax               ; Get pointer to PT3 in A,X
    ply                     ; Put loop pref into Y
    jmp _dfcl0__PT3START

; void dfcl_ptrun(unsigned char state);
_dfcl_ptrun:
    tax                     ; Check for zero
    beq _dfcl_ptstop
    jmp _dfcl0__PT3RESUME

; void dfcl_ptstop();
_dfcl_ptstop:
    jmp _dfcl0__PT3PAUSE

; char dfcl_ptload(char *fname, unsigned char *ptr);
_dfcl_ptload:
    jsr pushax              ; Remember address
    lda #2                  ; Using SD card device
    jsr _dfcl0_io_active_device
    jsr popptr1             ; Get address into ptr1
    jsr popax               ; Get filename in AX
    pha                     ; Put filename in to XA
    txa
    plx
    jsr _dfcl0_io_open_read ; Open the device for reading
    bcc dfcl_ptload_ok
    jsr _dfcl0_io_set_default
    lda #255              ; Error = -1
    tax
    rts
dfcl_ptload_ok:
	; Save current port B status of both VIAs
	lda _dfcl0_IO_0+_dfcl0_PRB	; VIA0 port B is the ROM and RAM bank select
	pha
	and #%11001111				; Mask off RAM bank bits
	ora #%00100000				; Select bank 2
	pha							; Save new bank select
	lda _dfcl0_IO_1+_dfcl0_PRB	; VIA1 port B controls ROM enable
	pha
	and #%11011111				; Disable ROM bit
	pha							; Save ROM disable state
	; Stack contains:
	;	101,x = disable ROM value
	;	102,x = original ROM value
	;	103,x = new RAM bank select value
	;	104,x = original RAM bank select value
    tsx                         ; Offset into cpu stack
dfcl_ptload_byte:
	jsr _dfcl0_io_get_ch		; Get a byte
	bcs df_rt_ptload_done		; If EOF then done
    php
    sei
    ldy $101,x                  ; ROM disable value
    sty _dfcl0_IO_1+_dfcl0_PRB
    ldy $103,x                  ; RAM bank 2
    sty _dfcl0_IO_0+_dfcl0_PRB
    sta (ptr1)                  ; Save byte to RAM Bank 2
    ldy $102,x                  ; ROM original value
    sty _dfcl0_IO_1+_dfcl0_PRB
    ldy $104,x                  ; RAM original bank
    sty _dfcl0_IO_0+_dfcl0_PRB
    plp                         ; Restore interrupts
    inc ptr1                    ; Increment pointer
    bne dfcl_ptload_byte        ; Back for another byte
    inc ptr1+1                  ; Increment high byte of ptr
    bra dfcl_ptload_byte        ; Back for another byte
df_rt_ptload_done:
    pla                         ; Tidy CPU stack
    pla
    pla
    pla
    jsr _dfcl0_io_close
    jsr _dfcl0_io_set_default
    lda #0                      ; Good = 0
    tax
    rts


; ** Sprites **
; void dfcl_sprpat(unsigned char nme, unsigned char *pat);
_dfcl_sprpat:
    sta _dfcl0_df_tmpptrb       ; Save *pat
    stx _dfcl0_df_tmpptrb+1

    jsr popa                    ; A=spr
    tax
    jsr __switch_bank1
    jmp _dfcl1_dfcl_sprpat

; void _dfcl_sprpos(unsigned char spr, unsigned char x, unsigned char y) {
_dfcl_sprpos:
    sta _dfcl0_df_tmpptrc           ; Save y
    jsr popa                        ; Get x
    sta _dfcl0_df_tmpptrb           ; Save
    jsr popa                        ; Get spr
    sta _dfcl0_df_tmpptra           ; Save
	; calculate the sprite number in vram
	asl a
	asl a
	adc _dfcl0_vdp_base+_dfcl0_vdp_addr_spa
	tax
	lda _dfcl0_vdp_base+_dfcl0_vdp_addr_spa+1
	adc #0
	sei
	jsr _dfcl0_vdp_wr_addr
	; now write the vertical position (tmpc, not b)
	lda _dfcl0_df_tmpptrc
	jsr _dfcl0_vdp_wr_vram
	; now write the horizontal position (tmpb)
	lda _dfcl0_df_tmpptrb
	jsr _dfcl0_vdp_wr_vram
	cli
	rts

; common routine for col and nme variations
; A contains offset in to sprite table to update
df_rt_spriteattr:
    phx
    sta _dfcl0_df_tmpptrb           ; Save last parm
    jsr popa                        ; Get spr#
    sta _dfcl0_df_tmpptra
	; calculate the sprite number in vram
	asl a
	asl a
	adc _dfcl0_vdp_base+_dfcl0_vdp_addr_spa
	sta _dfcl0_df_tmpptra
	lda _dfcl0_vdp_base+_dfcl0_vdp_addr_spa+1
	adc #0
	sta _dfcl0_df_tmpptra+1
	; add offset and put in X,A to set VRAM address
	pla							; get offset
	adc _dfcl0_df_tmpptra
	tax
	lda _dfcl0_df_tmpptra+1
	adc #0
	tay
	lda _dfcl0_df_tmpptrb
	jmp _dfcl0_vdp_poke

; void _dfcl_sprcol(unsigned char spr, unsigned char col) {
_dfcl_sprcol:
	; offset is 3 for colour byte
	ldx #3
	jmp df_rt_spriteattr

; void dfcl_sprnme(unsigned char spr, unsigned char nme);
_dfcl_sprnme:
	; offset is 2 for name byte
	ldx #2
	jmp df_rt_spriteattr


; ** File handling **

; return filename in X,A pointer
dfcl_parse_filename:
    lda #2                      ; Set device to SD card
    jsr _dfcl0_io_active_device
    jsr popax                   ; Get filename off C stack
    pha                         ; Swap X,A to A,X
    txa
    plx
    rts

; char dfcl_chdir(char *dir);
_dfcl_chdir:
    jsr __switch_bank2
    pha                         ; Swap X,A to A,X
    txa
    plx
    jsr _dfcl2_fs_chdir_w
    lda #0
    bcc dfcl_chdir_ok
    lda #255
dfcl_chdir_ok:
    tax
    rts


; Common for vload, bload, font
dfcl_bload_sub:
    php
    phy
    phx                         ; Save the address on cpu stack but X=high, A=low
    pha
    jsr dfcl_parse_filename
    jsr _dfcl0_io_open_read
    bcs dfcl_bload_err
    jsr __switch_bank1
    jmp _dfcl1_df_rt_bload_dfcl
dfcl_bload_err:
    pla                         ; Tidy stack
    pla
    pla
    pla
    rts

dfcl_bload_common:
    jsr dfcl_bload_sub
    lda #0
    bcc dfcl_bload_ok
    lda #255
dfcl_bload_ok:
    tax
    rts

; char dfcl_vload(char *fname, unsigned int vaddr)
_dfcl_vload:
    ; A,X = vaddr
    ldy #7                      ; Fixed header
    clc                         ; Hardcode for vram
    jmp dfcl_bload_common

; char dfcl_font(char *fname)
_dfcl_font:
    ; A,X = fname, need to put on C stack
    jsr pushax
	clc							; Set to video
	ldy #0						; No header
	ldx #1						; 0x100 address - hi
	lda #0						; 0x100 address - lo
    jmp dfcl_bload_common

; char dfcl_bload(char *fname, unsigned int vaddr)
_dfcl_bload:
    ; A,X = vaddr
    ldy #0                      ; No header
    sec                         ; Hardcode for cpu ram
    jmp dfcl_bload_common
