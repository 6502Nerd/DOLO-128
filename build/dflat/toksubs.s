;**********************************************************
;*
;*	DOLO-1 HOMEBREW COMPUTER
;*	Hardware and software design by Dolo Miah
;*	Copyright 2014-18
;*  Free to use for any non-commercial purpose subject to
;*  full credit of original my authorship please!
;*
;*  TOKSUBS.S
;*  Module that implements the tokenisation of keywords.
;*  When a line is being parsed, the index of the keyword
;*  found in the symbol table is used to call a routine
;*  here.  The job of a routine here is then to further
;*  parse the raw input e.g. a command that takes two input
;*  parameters, need to do what it needs to identify those.
;*  Despite the number of keywords in dflat, this isn't
;*  anywhere near the size of rtsubs.s (the runtime
;*  equivalent of this) because there is so much in common
;*  synactically.
;*  The tokenised output is put in to its own buffer and
;*  if the whole input was tokenised successfully then
;*  dflat will either try and execute (if in immediate
;*  mode), or save it to program memory in line number
;*  order.
;*
;**********************************************************

	; ROM code
	code  


;* General routine to tokenise a mandatory variable
df_tk_variable
	jsr df_tk_skip_ws
	; tokenise a variable
	jsr df_tk_peek_buf
	jsr df_tk_isalpha
	bcc df_tk_error
	lda #0
	rts

;****************************************
;* Parse assignment preamble
;****************************************
df_tk_preassign
	; Put assignment token
	; assume its a numeric int for now
	lda #0x80
	jsr df_tk_put_tok
	
	; first find or create a variable
	jsr df_tk_variable
	jsr df_tk_var
	; next char sound be =
	lda #'='
	jsr df_tk_expect_tok_err
	; skip more ws
	jsr df_tk_skip_ws
	; should not be at end of line
	jsr df_tk_peek_buf
	beq df_tk_parse_ass_err
	clc
	rts
df_tk_parse_ass_err
df_tk_error
	SWBRK DFERR_SYNTAX

;****************************************
;* Parse numeric assignment
;****************************************
df_tk_assign
	jsr df_tk_preassign
	; tokenise an expression (int or byte)
	jsr df_tk_expression
	clc
	rts


df_tk_comment
	; copy all subsequent chars to token
	jsr df_tk_get_buf
	beq df_tk_comment_done
	jsr df_tk_put_tok
	bra df_tk_comment
df_tk_comment_done
	clc
	rts

; Utility to get procedure name with _
df_tk_listp_procname
	; try and find the first proc
	lda #'_'
	jsr df_tk_expect_tok
	bcs df_tk_listp_procname_err
	; now get first alpha then all alphanum
	jsr df_tk_peek_buf
	jsr df_tk_isalpha
	bcc df_tk_listp_procname_err
df_tk_listp_procname_ch
	jsr df_tk_peek_buf
	jsr df_tk_isalphanum
	bcc df_tk_listp_procname_ok
	jsr df_tk_get_buf
	jsr df_tk_put_tok
	bra df_tk_listp_procname_ch
df_tk_listp_procname_ok
	clc
	rts
df_tk_listp_procname_err
	sec
	rts

df_tk_list
	jsr df_tk_listp_procname
	; if not found try '*' or normal list
	bcs df_tk_list_procs
	; the '-' allows to list to end
	lda #'-'
	; find and add if it exists
	jsr df_tk_expect_tok
	bra df_tk_list_done
	; '*' means list procs
df_tk_list_procs
	; try and find the first proc
	lda #'*'
	jsr df_tk_expect_tok
	bcc df_tk_list_done
	; else normal line number
df_tk_list_line
	; tokenise an expression
	jsr df_tk_expression
	; if not at the end then keep going
	lda #','
	jsr df_tk_expect_tok
	bcs df_tk_list_done
	; else get the next expression
	jsr df_tk_expression	
df_tk_list_done
	clc
	rts

df_tk_printat
	; Must get 2 parms for x,y
	jsr df_tk_2parms
	; if not at the end then keep going
	lda #','
	jsr df_tk_expect_tok
	bcc df_tk_print
	; else done
	clc
	rts
df_tk_data
df_tk_println
df_tk_print
df_tk_asm_db
df_tk_asm_dw
	; tokenise an expression
	jsr df_tk_expression
	; is there more to come?
	lda #','
	jsr df_tk_expect_tok
	bcs df_tk_print_done
	bra df_tk_print
df_tk_print_done
	clc
	rts

df_tk_input
	jsr df_tk_skip_ws
	; tokenise a variable
	jsr df_tk_variable
	jsr df_tk_var
	; either cc or cs depending on error condition
	rts
	
df_tk_read
	; tokenise a variable
	jsr df_tk_variable
	jsr df_tk_var
	; if not at the end then keep going
	lda #','
	jsr df_tk_expect_tok
	bcc df_tk_read
	clc
	rts

df_tk_dim
df_tk_redim
	; tokenise a variable
	jsr df_tk_variable
	jsr df_tk_arrvar
	; if not at the end then keep going
	lda #','
	jsr df_tk_expect_tok
	bcc df_tk_dim
	clc
	rts

df_tk_local
	jsr df_tk_skip_ws
	; tokenise a variable
	jsr df_tk_variable
	jsr df_tk_localvar
	; if not at the end then keep going
	lda #','
	jsr df_tk_expect_tok
	bcc df_tk_local
	clc
	rts

; A = 0 : Def
; A = 1 : Call
df_tk_def
	lda #0
	jsr df_tk_proc
	rts


; syntax : for %a=1,10,1
df_tk_for
	jsr df_tk_skip_ws

	; tokenise the for variable
	lda #DFVVT_INT
	jsr df_tk_var

	; always expect '='
	lda #'='
	jsr df_tk_expect_tok_err

	; starting value
	jsr df_tk_expression
	
	; always expect ',' separator
	lda #','
	jsr df_tk_expect_tok_err

	; ending value
	jsr df_tk_expression
	
	; always expect ',' separator
	lda #','
	jsr df_tk_expect_tok_err
	
	; step value
	jsr df_tk_expression
df_tk_for_done
	clc
	rts
	
; call to proc should not occur by itself
df_tk_callproc
	sec
	rts

; timer reset expects an int variable only
df_tk_reset
	jsr df_tk_skip_ws

	; tokenise a variable
	lda #DFVVT_INT
	jsr df_tk_var
	rts

; date time expects a string variable only
df_tk_datetime
	jsr df_tk_skip_ws

	; tokenise a variable
	lda #DFVVT_STR
	jsr df_tk_var
	rts

; These functions expect 1 parmeter
df_tk_len
df_tk_chr
df_tk_key
df_tk_get
df_tk_stick
df_tk_deek
df_tk_vpeek
df_tk_peek
df_tk_nvpeek
df_tk_mem
df_tk_rnd
df_tk_hex
df_tk_dec
df_tk_asc
df_tk_val
df_tk_sgn
df_tk_fcreate
df_tk_fopen
	jsr df_tk_expression
df_tk_closebrkt
	lda #')'
	jsr df_tk_expect_tok_err
	rts

; This function expects a variable only
df_tk_addr
df_tk_elapsed
	jsr df_tk_variable
	jsr df_tk_var
	; must have close braket
	jmp df_tk_closebrkt

; These functions expect 2 parameters
df_tk_left
df_tk_right
df_tk_scrn
df_tk_pixel
	jsr df_tk_2parms
	jmp df_tk_closebrkt

; These functions expect 3 parameters
df_tk_mid
	jsr df_tk_3parms
	jmp df_tk_closebrkt

; These functions expect 4 parameters
df_tk_call
	jsr df_tk_2parms
	lda #','
	jsr df_tk_expect_tok_err
	jsr df_tk_2parms
	jmp df_tk_closebrkt

;all these commands require no parameters
df_tk_else
df_tk_endif
df_tk_enddef
df_tk_abort
df_tk_repeat
df_tk_next
df_tk_wend
df_tk_run
df_tk_add
df_tk_sadd
df_tk_dir
df_tk_dirl
df_tk_cls
df_tk_new
df_tk_mult
df_tk_div
df_tk_mod
df_tk_asl
df_tk_lsr
df_tk_sub
df_tk_and
df_tk_or
df_tk_eor
df_tk_lte
df_tk_lt
df_tk_gte
df_tk_gt
df_tk_ne
df_tk_eq
df_tk_monitor
df_tk_fclose
;df_tk_retsub
	clc
	rts

; 0 or 1 parameter special!
df_tk_return
	jmp df_tk_expression

; These commands expect 1 parameter	
df_tk_while
df_tk_until
df_tk_if
df_tk_elseif
df_tk_wait
df_tk_cursor
df_tk_mode
df_tk_del
df_tk_chdir
df_tk_mkdir
df_tk_hires
df_tk_load
df_tk_save
df_tk_pixmode
df_tk_pixmask
df_tk_pixcol
df_tk_put
df_tk_himem
df_tk_font
df_tk_device
df_tk_ptrun
;df_tk_goto
;df_tk_gosub

df_tk_asm_org
df_tk_asm_opt
df_tk_asm_ds

	; first parm
	jsr df_tk_expression
	rts

; These commands expect 2 numeric parameters
df_tk_setvdp
df_tk_spritepat
df_tk_spritecol
df_tk_spritenme
df_tk_vpoke
df_tk_poke
df_tk_doke
df_tk_nvpoke
df_tk_point
df_tk_vload
df_tk_ptload
df_tk_ptinit
df_tk_2parms
	; first parm
	jsr df_tk_expression
	lda #','
	jsr df_tk_expect_tok_err
	; tokenise second parm
	jsr df_tk_expression
	rts

; these commands expect 3 numeric parameters
df_tk_hplot
df_tk_plot
df_tk_circle
df_tk_sound
df_tk_colour
df_tk_spritepos
df_tk_shape
df_tk_renum
df_tk_3parms
	jsr df_tk_2parms
	lda #','
	jsr df_tk_expect_tok_err
	; tokenise third parm
	jsr df_tk_expression
	rts

; these commands expect 4 numeric parameters
df_tk_play
df_tk_music
df_tk_line
df_tk_box
df_tk_bload
df_tk_4parms
	jsr df_tk_2parms
	lda #','
	jsr df_tk_expect_tok_err
	jsr df_tk_2parms
	rts

; these commands expect 5 numeric parameters
df_tk_sprite
df_tk_bsave
df_tk_5parms
	jsr df_tk_4parms
	lda #','
	jsr df_tk_expect_tok_err
	jsr df_tk_expression
	rts

