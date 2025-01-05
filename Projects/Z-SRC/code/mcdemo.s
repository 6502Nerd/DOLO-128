;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-24
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  MCDEMO.S
;*	Demonstration of cross assembling on PC that results
;*	in a binary that can be loaded directly without need
;*	of assembling using dflat
;*
;**********************************************************

;* Include consolidated definitions to access common
;* routines and locations
	include "a-files\all.i"


;****************************************
;*	Set default start of code section
;*  bss and data not set.
;****************************************
	code				; Code section 
;	org mem_start		; Start of free space for dflat
	org 0x1000			; Normal start is at 0x1000

_my_mc_start
	; X,Y is the address, A ignored
	sty tmp_a
	ldy #0
hello_char
	lda hello_msg,y
	beq hello_done
	phy
	ldy tmp_a
	jsr vdp_poke
	inc tmp_a
	ply
	iny
	bne hello_char
hello_done
	ldy tmp_a
	rts
hello_msg
	db "Hello world!",0
_my_mc_end