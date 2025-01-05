;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  KERNEL.S
;*	The 'kernel' routine includes code and data which must
;* 	be in every ROM bank.  In the auto-generated bank#.s
;*  files, the kernel is added before the bank specific
;*	code.  See bank0.s as an example.
;*
;**********************************************************

;* Include all definition and code files in the right order
	include "inc\includes.i"
	include "inc\graph.i"
	include "io\io.i"
	include "rtc\rtc.i"
	include "dflat\dflat.i"
	include "dflat\dflat.i"
	include "dflat\error.i"
	include "bank\bank.i"
	include "kernel\zeropage.i"


;****************************************
;*	Set 6502 default vectors	*
;****************************************
	data				; Set vectors
	org 0xfffa			; Vectors lie at addresses
	fcw call_nmi_master	; 0xfffa : NMI Vector
	fcw init			; 0xfffc : Reset Vector
	fcw call_irq_master	; 0xfffe : IRQ Vector
	
	; ROM code
	code				;  
	org 0xc000			; Start of ROM

	; The bank number is hardwired and aligned to PB6,7
bank_num
	if BANK0
	  db 192
	endif
	if BANK1
	  db 128
	endif
	if BANK2
	  db 64
	endif
	if BANK3
	  db 0
	endif

_code_start
	; Restore current bank always at address c001
_OSVectors
	include "kernel\osvec.s"
_restore_bank
	; Save A
	sta tmp_bank1
	; Get old bank from stack
	pla
	sta tmp_bank2
	lda IO_0+PRB
	and #ROM_ZMASK
	ora tmp_bank2
	sta IO_0+PRB
	
	; Restore A
	lda tmp_bank1

	rts

	; include cross-bank functions (see extern.mak)
	include "bank\autogen.s"	
	
mod_sz_kernel_s

;* Include all common code in the right order
	include "io\io.s"
	include "kernel\vdp-low.s"
	include "kernel\snd-low.s"
	include "kernel\main.s"
	include "kernel\irq.s"
	include "utils\misc.s"
	include "utils\utils.s"

;* Reset vector points here - 6502 starts here
init
;	jmp init_test
	; First clear ram
;	sei					; No need as disabled on startup
;	cld					; No need as disabled on startup
	ldx #0xff			; Initialise stack pointer
	txs
	jmp init_ram		; jmp not jsr to ram initialiser
init_2					; init_ram will jump back to here
	
	jsr kernel_init

	jmp main

kernel_init
	jsr init_nmi		; Initialise NMI handling
	jsr init_irq		; Initialise IRQ handling
	jsr _init_acia		; initialise the serial chip
	
	jsr _init_cia0		; initialise cia 0
	jsr _init_cia1		; initialise cia 1

kernel_test
	jsr _init_snd		; initialise the sound chip
	jsr _init_keyboard	; initialise keyboard timer settings
	jsr _vdp_init		; initialise vdp
	lda #0				; Default = 40 column mode - put on stack
	pha
	ldx #NV_MODE		; NV location for default text mode [can read NV ram without initialising RTC]
	jsr _rtc_nvread		; Try to read location
	bcs kernel_skip_nv	; If bad NV ram then skip trying to read settings
	tax					; Save the mode temporarily
	pla					; Get the default mode from stack
	txa					; And push the NV mode that was read
	pha
	ldx #NV_COLOUR		; NV location for the default colour
	jsr _rtc_nvread		; Try to read location (assumed good as previous was good)
	sta vdp_base+vdp_bord_col	; Save it to the border colour
kernel_skip_nv	
	pla					; Get the mode (either default or the NV value)
	jsr _gr_init_screen
	jsr io_init			; Set default input/output device
	cli					; irq interrupts enable

	; Print the boot up message - requires IO and IRQ
	_println msg_hello_world


	jsr _rtc_init		; Initialise RTC - * AFTER INTERRUPTS ENABLED as IO is used *
	jsr _init_sdcard	; initialise the sd card interface
	jsr _init_fs		; initialise the filesystem
	jsr _df_init		; Initialise interpreter

	rts

	
;* Initialises RAM, skipping pages 4-8 which are for IO
;* Zeroes all addressable RAM in the default bank i.e. up to 0xffff
init_ram
	stz 0x00			; Start at page 0
	stz 0x01
	ldy #0x02			; But Y initially at 2 to not overwrite pointer
	ldx #0x00			; Page counter starts at zero
	lda #0				; Normal RAM filled with zero
init_ram_1
	cpx	#5				; Page <5 is ok (zeroes out VIA0 and 1)
	bcc init_ram_fill
	cpx #8				; Page >=8 is ok
	bcc init_ram_skip	; But >=5 and <8 do not initialise
init_ram_fill
	sta (0x00),y		; Write initialisation value to RAM
	iny
	bne init_ram_fill	; Do a whole page
init_ram_skip
	inx					; Increment page counter
	stx 0x01			; Save to address pointer
	bne init_ram_1		; Do all pages until page 0xff done and X wraps to 0
	
	jmp init_2			; Carry on initialisation

mod_sz_kernel_e

