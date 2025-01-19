; =======================================================================================
; Vortex Tracker II v1.0 PT3 player for 6502
; Based on ORIC 1/ATMOS (6502) version
; Updated for HB-BBC-128 Homebrew Computer by 6502Nerd
; ScalexTrixx (A.C) - (c)2018
;
; Translated and adapted from ZX Spectrum Player Code (z80)  
; by S.V.Bulba (with Ivan Roshin for some parts/algorithm)
; https://bulba.untergrund.net/main_e.htm (c)2004,2007 
;
Revision = "0" 
; =======================================================================================
; REV 0: 
; ======
; rev 0.34 (WK/TS)  - correction / 1.773 (288=x256+0x32 -> 289=x256+x32+x01)
;                   => file_end = $8E68
;
; rev 0.33 (WK)     - optimizations: PTDECOD
;                   => file_end = $8E53
;
; rev 0.32 (WK)     - optimizations: PLAY
;                   => file_end = $8F43
;
; rev 0.31 (WK)     - optimizations: CHREGS
;                   => file_end = $8FC4
;
; rev 0.30 (WK)     - New base "full working" version for optimizations
;                   - optimizations: zp variables / CHECKLP / INIT (ALL)
;                   => file_end = $9027
;
; --------------------------------
; WK: working / TS: test version |
; =======================================================================================
; TODO:
; - lda ($AC),y -> lda ($AC,x)
; - NOISE Register opt (/2 ?)
; - déplacer / 1.773 avant CHREGS (cf CPC version) => vraiment utile ?!
; - dans PD_LOOP: vérifier si des jmp relatifs sont possibles
; - fix .bbs address
; - check zero pages addresses
; =======================================================================================
;
;	ORG $8000
;
; -------------------------------------
        bss

	org $ed         ; Uses *all* of zero page from here!
    
SETUP   ds 1      ; set bit0 to 1, if you want to play without looping
                   ; bit7 is set each time, when loop point is passed
; "registers" Z80
; A = A
; F = flags

z80_A   ds 1      ; save A
z80_C   ds 1
z80_B   ds 1
z80_E   ds 1
z80_D   ds 1
z80_L   ds 1
z80_H   ds 1
z80_IX  ds 2
z80_AP  ds 1      ; save A'
; temp variable used during play
val1    ds 2
val2    ds 2
val3    ds 2
val4    ds 2
TA1 = val1
TA2 = val1+1
TB1 = val2
TB2 = val2+1
TC1 = val3
TC2 = val3+1
TB3 = val4
TC3 = val4+1

; =====================================
; module PT3 address
; =====================================
        code
; For dflat, allow build of code for other locations
; default is 0xe000

 if !PT3RELOCADDR
PT3RELOCADDR = 0xe000
 endif
        org $e000

; START = $e000 or PT3RELOCADDR
; START+00 : Initialise a tune and start
; START+03 : Disable tune and stop
; START+06 : Mute sound every interrupt
; START+09 : Pause but allow other sounds while paused
; START+0C : Resume tune
; All will be extern routines
PT3START
        jmp _doStart
PT3PAUSE
        jmp _doPause
PT3RESUME
        jmp _doResume

; We need to copy all this code to shadow RAM behind ROM!
; Also ensure we're in **Bank 2** (not Bank 3) of RAM!
; This is an extern routine needs to be callable from anywhere
; Is called at power-on / reset
PT3INIT
        ; Swtich to RAM bank 2 don't touch anything else
        lda IO_0+PRB
        pha                     ; Remember the bank #
        and #0b11001111         ; mask out old bank #
        ora #0b00100000         ; mask in bank binary 10 = 2dec
        sta IO_0+PRB

        ; Copy from PT3START to PT3END
        ; To shadow RAM directly underneath
        ldy #lo(PT3START)
        ldy #0x00
        sty tmp_a               ; Page + Y index, page lo always 0
        ldx #hi(PT3START)
        ldx #0xc0
        stx tmp_a+1

PT3INIT_COPY
        lda (tmp_a),y           ; Get ROM byte
        sta (tmp_a),y           ; Write to memory address always goes to active RAM bank
        iny
        bne PT3INIT_COPY
        inx
        stx tmp_a+1             ; Increment page number
        bne PT3INIT_COPY

        ; Ok all code in this file copied from ROM to RAM
        pla
        sta IO_0+PRB            ; Restore RAM bank #
        rts


; Can play other sounds while paused
_doPause
        ; Disable T1 interrupt on VIA 1
        lda #0b01000000
        sta IO_1+IER

        ; Kill the channels with the sound through control register
        ldy #0b00111111
        ldx #SND_REG_CTL
        jsr snd_set
        rts

; Reinstate the PT3 IRQ
_doResume
        ; Enable T1 interrupt on VIA 1
        lda #0b11000000
        sta IO_1+IER
        rts


; Initialise the player to start using A,X as song address

_doStart
; For dflat, assume that A,X provides address of song module
        sta z80_L
        stx z80_H
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
;        bra _doStart_test

	jsr INIT
        ; Remember previous user irq
        lda int_usercia1
        sta oldIrq
        lda int_usercia1+1
        sta oldIrq+1
        ; Set up timer for 50Hz (20ms) interrupts
        ; @5.36MHz it is 107,200 cycles
        ; which doesn't fit into 16 bits!
        ; so instead set up 100Hz (10ms) interrupts
        ; which is 53,600 cycles, but only
        ; invoke the sound player every other
        ; interrupt!
        ; 53,600 = 0xd160
        ; Timre 1 of VIA 1
        lda #0x60
        sta IO_1+T1CL
        lda #0xd1
        sta IO_1+T1CH
        ; T1 of VIA1 set to continuous
        lda #0b01000000
        sta IO_1+ACR
        ; Instate PT3 irq
        lda #lo(pt3Irq)
        sta int_usercia1
        lda #hi(pt3Irq)
        sta int_usercia1+1
        ; Enable T1 interrupt
        lda #0b11000000
        sta IO_1+IER
;_doStart_test
        ; Restore ROM
        pla                             ; Get original port setting
        sta IO_1+PRB                    ; Update port to activate setting
        ; Restore RAM bank
        pla                             ; Get original port setting
        sta IO_0+PRB                    ; Update port to activate setting
        rts
     
CrPsPtr	fcw 0 ; current position in PT3 module
intCount fcb 0      ; byte flag to call player only every other interrupt
oldIrq fcw 0    ; Remember old IRQ vector

;Identifier
	    db "=VTII PT3 Player r.",Revision,"="

;
; Call pt3 player every interrupt
pt3Irq
        ; Call player every other interrupt
        lda #0x80
        eor intCount
        sta intCount
        bpl skipInt_1
        ; Call the player each tick
        jsr PLAY
skipInt_1
skipInt
        rts

CHECKLP
	                                                
        lda SETUP                                                   
        ora #%10000000                                              
        sta SETUP
	lda #%00000001                                                                                               
        bit SETUP
        bne s1                                                      
	rts
s1	pla                                                         
        pla       ; dépile 2 fois puisque rts shunté
	inc DelyCnt                                                                                                                                    
        inc ANtSkCn                                                 
_MUTE	                                                            
        lda #00                                                     
        sta z80_H                                                   
	sta z80_L                                                   
	sta AYREGS+AmplA                                            
	sta AYREGS+AmplB                                            
        sta AYREGS+AmplC
        sta AYREGS+Mixer  ; This is the daddy - switch off all channels and noise
	jmp ROUT                                              

INIT
	lda z80_L                                                   
	sta MODADDR+1
        sta MDADDR2+1
        sta z80_IX
        pha
        lda z80_H
        sta MODADDR+7
        sta MDADDR2+7
        sta z80_IX+1
        pha
        lda #lo(100)                                                   
        sta z80_E
        lda #00
        sta z80_D
        tay
	clc                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H
        lda (z80_L),y                                               
	sta Delay+1                                                                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        sta CrPsPtr                                                 
        lda z80_H
        adc #00
        sta z80_H    
        sta CrPsPtr+1
	ldy #102               
        lda (z80_IX),y
        sta z80_E
	clc                                                         
        adc z80_L
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H       
	inc z80_L                                                   
        bne s2
        inc z80_H
s2	lda z80_L                                                   
        sta LPosPtr+1
        lda z80_H
        sta LPosPtr+5
	pla                                                         
        sta z80_D
        pla
        sta z80_E
	ldy #103               
        lda (z80_IX),y
	clc                                                         
        adc z80_E
        sta PatsPtr+1   
        ldy #104                  
        lda (z80_IX),y
        adc z80_D
        sta PatsPtr+8
        lda #lo(169)                                                   
        clc                                                         
        adc z80_E
        sta OrnPtrs+1   
        lda #00
        adc z80_D
        sta OrnPtrs+8
        lda #lo(105)                                                   
        clc                                                         
        adc z80_E
        sta SamPtrs+1
        lda #00
        ;INIT zeroes from VARS to VAR0END-1 (area < $80)           
        ldy #(VAR0END-VARS-1)
LOOP_LDIR 
        sta VARS,y
        dey         ; (carry not modified)
        bpl LOOP_LDIR
        ; A = #00  
        adc z80_D
        sta SamPtrs+8                                        
        lda SETUP                                                   
        and #%01111111
        sta SETUP
        
	lda #lo(T1_)
        sta z80_E
        lda #hi(T1_)
        sta z80_D
        lda #$01                                   
	sta DelyCnt                                                                                                  
        sta ANtSkCn
        sta BNtSkCn
        sta CNtSkCn
        lda #$F0
	sta AVolume                                                 
	sta BVolume                                                 
	sta CVolume                                                 
        lda #lo(EMPTYSAMORN)                                           
        sta z80_L
        sta AdInPtA+1
        sta AOrnPtr
        sta BOrnPtr
        sta COrnPtr
        sta ASamPtr
        sta BSamPtr
        sta CSamPtr
        lda #hi(EMPTYSAMORN)
        sta z80_H
	sta AdInPtA+5                                               
	sta AOrnPtr+1                                               
	sta BOrnPtr+1                                               
	sta COrnPtr+1                                               
	sta ASamPtr+1                                               
	sta BSamPtr+1                                               
	sta CSamPtr+1                                               
	    			                                                
        
	ldy #13                    
        lda (z80_IX),y
        sec                                                         
        sbc #$30        ; ascii value - 30 = version number (1-7)
	bcc L20         ; inverse (pour SUB aussi)                  
	cmp #10                                                     
	bcc L21         ; < 10                                      
L20	    
        lda #6          ; version par defaut si incorrect           
L21	    
        sta Version+1                                               
	pha             ; save version nb
        cmp #4          ; version 4 ?                               
        bcc s7b         ; < 4 (inverse carry)
        clc
        bcc s8b         ; always
s7b     sec
s8b     ldy #99                 
        lda (z80_IX),y  
        rol a           ; carry !                                   
	and #7          ; clear all bit except 0-1-2                
        tax             ; save A
;NoteTableCreator (c) Ivan Roshin
;A - NoteTableNumber*2+VersionForNoteTable
;(xx1b - 3.xx..3.4r, xx0b - 3.4x..3.6x..VTII1.0)

     	lda #lo(NT_DATA)											    
     	sta z80_L
     	lda #hi(NT_DATA)
     	sta z80_H
     	lda z80_E													
     	sta z80_C
     	lda z80_D
     	sta z80_B
     	lda #00
        tay           ; ldy #00	        
     	sta z80_D
     	txa           ; restore A									
     	asl a															
     	sta z80_E													
     	clc                                                         
        adc z80_L
        sta z80_L
        lda z80_D
        adc z80_H
        sta z80_H													
     	lda (z80_L),y												
     	sta z80_E
     	inc z80_L                                                   
        bne s9b
        inc z80_H
s9b 
	lsr z80_E											    				     				
	bcs sb		; si c = 0 => $EA (NOP) / si c = 1 => $18 (clc)
sa  	lda #$EA 	; -> $EA (NOP)
        bne sb1		; always	
sb	lda #$18	; -> $18 (clc) 									
sb1	sta L3		            									
	lda z80_E													
	ldx z80_L
	sta z80_L
	stx z80_E
	lda z80_D
	ldx z80_H
	sta z80_H
	stx z80_D
	clc                                                         
    	lda z80_C
    	adc z80_L
    	sta z80_L
    	lda z80_B
    	adc z80_H
    	sta z80_H

	lda (z80_E),y												
	clc                                                         
        adc #lo(T_)
	sta z80_C
        pha                                                   
        adc #hi(T_)                                                    
	sec                                                         
        sbc z80_C
        sta z80_B                                                   												
	pha

	lda #lo(NT_)											
	sta z80_E
	pha															
	lda #hi(NT_)
	sta z80_D
	pha
	lda #12														
	sta z80_B
L1	    
        lda z80_C													
	pha
	lda z80_B
	pha
	lda (z80_L),y												
	sta z80_C
	inc z80_L                                                   
        bne sc
        inc z80_H
sc     
	lda z80_L												    
	pha
	lda z80_H
	pha
	lda (z80_L),y												
	sta z80_B

	lda z80_E       												
	sta z80_L
        pha
	lda z80_D
	sta z80_H
        pha
	lda #lo(23)		    										
	sta z80_E
	lda #hi(23)
	sta z80_D
	lda #8														
	sta z80_IX+1
        
L2	    
        lsr z80_B													
	ror z80_C													
L3	    
	fcb $AC			; clc ($18) or NOP ($EA)
	lda z80_C													
	adc #00  		    								    	
	sta (z80_L),y												
	inc z80_L                                                   
        bne sd
        inc z80_H
sd      
        lda z80_B													
	adc #00 													
	sta (z80_L),y												
	clc                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        lda z80_D
        adc z80_H
        sta z80_H
	dec z80_IX+1											    
	bne L2														

	pla															
	sta z80_D
	pla         
        adc #02     
        sta z80_E   
        bcc sf      
        inc z80_D 

sf     
	pla												    	    
	sta z80_H
	pla
	sta z80_L
	inc z80_L                                                   
        bne sg
        inc z80_H
sg     
	pla												    	    
	sta z80_B
	pla
	sta z80_C
	dec z80_B													
	beq sg1
        jmp L1
sg1        
	pla															
	sta z80_H
	pla
	sta z80_L
	pla															
	sta z80_D
	pla
	sta z80_E
        								
	cmp #lo(TCOLD_1)		        								
        bne CORR_1													
	lda #$FD													
	sta NT_+$2E									 				

CORR_1	
        clc                                                         
        lda (z80_E),y																										
	beq TC_EXIT													
	ror a															
	php			    ; save carry														
	asl a															
	sta z80_C													
	clc                                                         
        adc z80_L
        sta z80_L
        lda z80_B
        adc z80_H
        sta z80_H                                
	plp             ; restore carry (du ror)	                
	bcc CORR_2                                                  
	lda (z80_L),y												
	sec															
	sbc #$02
	sta (z80_L),y
	
CORR_2	
        lda (z80_L),y												
	clc			
	adc #$01
	sta (z80_L),y
        sec   		                                                
	lda z80_L                                                   
	sbc z80_C
	sta z80_L
	lda z80_H
	sbc z80_B
	sta z80_H
	inc z80_E                                                   
        bne sh
        inc z80_D
sh     
	jmp CORR_1												    

TC_EXIT
	pla			; restore version number						

;VolTableCreator (c) Ivan Roshin
;A - VersionForVolumeTable (0..4 - 3.xx..3.4x;
;5.. - 3.5x..3.6x..VTII1.0)

	cmp #5		; version 										
	lda #lo($11)                                                   
	sta z80_L
        lda #hi($11)													
	sta z80_H													
	sta z80_D                                                   
	sta z80_E													
	lda #$2A	; ($2A = rol A)								    
	bcs M1		; CP -> carry inverse (CP 5)					
	dec z80_L													
	lda z80_L													
	sta z80_E
	lda #$EA	; ($EA = NOP)			    					
M1          
        sta M2														
	lda #lo(VT_+16)												
	sta z80_IX
	lda #hi(VT_+16)
	sta z80_IX+1
	lda #$10													
	sta z80_C

INITV2  
        clc
        lda z80_L													
	pha
        adc z80_E
        sta z80_E
	lda z80_H
	pha
        adc z80_D
        sta z80_D
	    
        lda #00														
	sta z80_L
	sta z80_H
        clc
INITV1  
        lda z80_L													
M2          
        fcb $AC	    ; $EA (nop) ou $2A (rol)
	lda z80_H													
	adc #00			; + carry                                  	
	sta (z80_IX),y												
	inc z80_IX                                                  
        bne si
        inc z80_IX+1
si     
	clc                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        lda z80_D
        adc z80_H
        sta z80_H
	inc z80_C												    
	lda z80_C													
	and #15														
        clc         ; carry cleared by and
	bne INITV1													

	pla															
	sta z80_H
	pla
	sta z80_L
	lda z80_E													
	cmp #$77													
	bne M3														
	inc z80_E													
M3      
        clc                                                         
        lda z80_C																								
	bne	INITV2													

	jmp ROUT													
; ==============================================================================================
; Pattern Decoder
PD_OrSm	
        ldy #Env_En     										    
	lda #00
	sta (z80_IX),y
	jsr SETORN													
	ldy #00					; lda ($AC,x)									
	lda (z80_C),y
	inc z80_C                                                   
        bne sj
        inc z80_B
sj     
	lsr a 													    
        bcc sj1
        ora #$80
sj1     
PD_SAM	
        asl a 											    		
PD_SAM_	
        sta z80_E													
SamPtrs		
	lda #$AC				
        clc
        adc z80_E
	sta z80_L
	lda #$AC
        adc #00
	sta z80_H

        ldy #00
	lda (z80_L),y
MODADDR		
	adc #$AC												
	tax             ; save
	iny                                                         
	lda (z80_L),y
        adc #$AC								    			

	ldy #SamPtr+1         										
	sta (z80_IX),y
	dey															
	txa         
	sta (z80_IX),y
	jmp PD_LOOP													

PD_VOL	
        asl a															
        adc #00
	asl a															
        adc #00
	asl a															
        adc #00
	asl a															
        adc #00
	ldy #Volume         										
	sta (z80_IX),y
        jmp PD_LP2													
	
PD_EOff	
        ldy #Env_En		    	        							
	sta (z80_IX),y
	ldy #PsInOr   			    					    		
	sta (z80_IX),y
	jmp PD_LP2													

PD_SorE	
        sec															
	sbc #01
        sta z80_A
	bne PD_ENV													
	ldy #00			        ; lda ($AC,x)												
	lda (z80_C),y
	inc z80_C                                                   
        bne sl
        inc z80_B
sl     
	ldy #NNtSkp    		        								
	sta (z80_IX),y
        jmp PD_LP2													

PD_ENV	
        jsr SETENV													
	jmp PD_LP2													

PD_ORN	
        jsr SETORN													
	jmp PD_LOOP													

PD_ESAM	
        ldy #Env_En	             									
	sta (z80_IX),y
	ldy #PsInOr	    		        							
	sta (z80_IX),y
	lda z80_A           
        beq sm														
	jsr SETENV
sm	ldy #00			    ; lda ($AC,x)												
	lda (z80_C),y
	inc z80_C                                                   
        bne sn
        inc z80_B
sn     
        jmp PD_SAM_								     			    

PTDECOD 
        ldy #Note   							    				
	lda (z80_IX),y
	sta PrNote+1												
	ldy #CrTnSl    		    						    		
	lda (z80_IX),y                                              
	sta PrSlide+1												
        iny 
	lda (z80_IX),y											
	sta PrSlide+8

PD_LOOP	
        lda #$10													
	sta z80_E
	
PD_LP2	
        ldy #00			    ; lda ($AC,x)												
	lda (z80_C),y
	inc z80_C                                                   
        bne so
        inc z80_B
so
	clc															
	adc #$10
	bcc so1
        sta z80_A            
        jmp PD_OrSm
so1     adc #$20                                                    
	bne so11													
        jmp PD_FIN
so11	bcc so2													    
        jmp PD_SAM
so2	adc #$10                                                    
	beq PD_REL													
	bcc so3 													
        jmp PD_VOL
so3	adc #$10                                                    
	bne so4										    			
        jmp PD_EOff
so4	bcc	so5												    	
	jmp PD_SorE
so5     adc #96                                                     
	bcs PD_NOTE													
	adc #$10                                                    
	bcc so6
        sta z80_A												    	
        jmp PD_ORN													
so6	adc #$20                                                    
	bcs PD_NOIS													 														
	adc #$10                                                    
        bcc so7
        sta z80_A												    	
        jmp PD_ESAM
so7	asl a															
	sta z80_E
        clc                                                   
        adc #lo(SPCCOMS+$FF20)							        
        sta z80_L
	lda #hi(SPCCOMS+$FF20)
        adc #00
	sta z80_H
        ; on doit inverser le PUSH car l'adresse sera utilisée après rts
        ldy #01	
	lda (z80_L),y												
	pha             ; push D
	dey                                                         
	lda (z80_L),y										        
	pha             ; push E
	jmp PD_LOOP													

PD_NOIS									
        sta Ns_Base                                                 
	jmp PD_LP2													

PD_REL	
        ldy #Flags   								    			
	lda (z80_IX),y
	and #%11111110
	sta (z80_IX),y
	jmp PD_RES													
	
PD_NOTE	
        ldy #Note    	 				    						
	sta (z80_IX),y	
	ldy #Flags      											
	lda (z80_IX),y
	ora #%00000001
	sta (z80_IX),y
	    													
PD_RES												
        lda #00	
        sta z80_L
	sta z80_H
	ldy #11
bres
	sta (z80_IX),y          
	dey
        bpl bres
PD_FIN	
	ldy #NNtSkp     						    				
	lda (z80_IX),y
	ldy #NtSkCn     		    								
	sta (z80_IX),y
	rts 														

C_PORTM
	ldy #Flags  												
	lda (z80_IX),y
	and #%11111011
	sta (z80_IX),y
	ldy #00			    ; lda ($AC,x)												
	lda (z80_C),y
        ldy #TnSlDl     				    			    		
	sta (z80_IX),y
        ldy #TSlCnt	        			    						
	sta (z80_IX),y

        clc
        lda z80_C
        adc #03
        sta z80_C
        bcc st
        inc z80_B
st     
	lda #lo(NT_)			; OPT										
	sta z80_E
	lda #hi(NT_)           ; OPT
	sta z80_D
	ldy #Note	        										
	lda (z80_IX),y
	ldy #SlToNt         										
	sta (z80_IX),y
	asl a																																																				
	clc                                                         
        adc z80_E           ; OPT
        sta z80_L
        lda z80_D           ; OPT
        adc #00           
        sta z80_H
        ldy #00	
	lda (z80_L),y 												
	pha	
	iny                                                         
	lda (z80_L),y 												
	pha
PrNote	
        lda #$3E													
	ldy #Note   					    						
	sta (z80_IX),y
	asl a																																			
	clc                                                         
        adc z80_E           ; OPT
        sta z80_L
        lda z80_D           ; OPT
        adc #00
        sta z80_H
	ldy #00
        lda (z80_L),y												
	sta z80_E
	iny                                                         
	lda (z80_L),y											    
	sta z80_D
	ldy #TnDelt 
        pla															
	sta z80_H
	pla       
	sec                                                                                                       
        sbc z80_E
        sta z80_L
        sta (z80_IX),y
        lda z80_H
        sbc z80_D
        sta z80_H 
        iny                                                         
        sta (z80_IX),y
	ldy #CrTnSl                                                 
        lda (z80_IX),y
        sta z80_E
	iny                                                         
        lda (z80_IX),y
        sta z80_D
Version
	lda #$3E                                                    
	cmp #6                                                      
	bcc OLDPRTM     ; < 6
        ldy #CrTnSl                                       
PrSlide	
        lda #$AC                                                    
        sta z80_E
        sta (z80_IX),y
        iny
        lda #$AC
        sta z80_D
        sta (z80_IX),y
	                                                  
OLDPRTM	
        ldy #00                                                     
        lda (z80_C),y
        iny                                                                                                                        
        sta z80_AP                                                  
	lda (z80_C),y                                               
	sta z80_A
        lda z80_C
        clc
        adc #02
        sta z80_C
        bcc sw
        inc z80_B
sw
	lda z80_A                                                   
	beq NOSIG                                                   
	lda z80_E													
	ldx z80_L
	sta z80_L
	stx z80_E
	lda z80_D
	ldx z80_H
	sta z80_H
	stx z80_D
NOSIG	
        sec                            
        lda z80_L
        sbc z80_E
        sta z80_L
        lda z80_H
        sbc z80_D
        sta z80_H
	bpl SET_STP                                                 
	lda z80_A                                                   
        eor #$FF                                                    
        ldx z80_AP                                                  
        sta z80_AP
        txa
	eor #$FF                                                    
        clc             
        adc #01                                                
        tax                                                         
        lda z80_AP
        stx z80_AP
        sta z80_A
SET_STP	
        ldy #(TSlStp+1)                                             
        lda z80_A
        sta (z80_IX),y                                              
        tax                                                         
        lda z80_AP
        stx z80_AP
        sta z80_A
	    dey                       
        sta (z80_IX),y
        ldy #COnOff                                                 
        lda #00
        sta (z80_IX),y
	rts                                                         

C_GLISS	
        ldy #Flags       											
	lda (z80_IX),y
	ora #%00000100
	sta (z80_IX),y
	ldy #00                 ; lda ($AC,x)	                                    
        lda (z80_C),y
        sta z80_A
        inc z80_C                                                   
        bne sy
        inc z80_B
sy     
	ldy #TnSlDl                                                 
        sta (z80_IX),y
	clc                                                         
        lda z80_A                                                   
	bne GL36                                                    
	lda Version+1                                               
	cmp #7                                                      
	bcs sz                                                      
        lda #00         ; si A < 7  , A = 0 ($FF+1)                 
        beq saa
sz      lda #01         ; si A >= 7 , A = 1 ($00+1)
saa	    
GL36	
        ldy #TSlCnt                                                 
	sta (z80_IX),y                                              
        ldy #00                                                     
        lda (z80_C),y
        sta z80_AP
        iny
        lda (z80_C),y
        sta z80_A
        clc
        lda z80_C
        adc #02
        sta z80_C                                                   
        bcc sac
        inc z80_B
sac     
	jmp SET_STP                                                 

C_SMPOS	
        ldy #00                  ; lda ($AC,x)	                                   
        lda (z80_C),y
        inc z80_C                                                   
        bne sad
        inc z80_B
sad     
	ldy #PsInSm                                                 
        sta (z80_IX),y
	rts                                                         

C_ORPOS	
        ldy #00                 ; lda ($AC,x)	                                              
        lda (z80_C),y
        inc z80_C                                                   
        bne sae
        inc z80_B
sae     
	ldy #PsInOr                                                 
        sta (z80_IX),y
	rts                                                         
    
C_VIBRT	
        ldy #00                 ; lda ($AC,x)	                                             
        lda (z80_C),y
        inc z80_C                                                   
        bne saf
        inc z80_B
saf     
	ldy #OnOffD                                                 
        sta (z80_IX),y
        ldy #COnOff                                                 
        sta (z80_IX),y
	ldy #00                 ; lda ($AC,x)	                                          
        lda (z80_C),y
        inc z80_C                                                   
        bne sag
        inc z80_B
sag     ldy #OffOnD                                                 
        sta (z80_IX),y
        lda #00                                                     
        ldy #TSlCnt                                                 
        sta (z80_IX),y
	ldy #CrTnSl                                                 
        sta (z80_IX),y
	iny                                                         
        sta (z80_IX),y
	rts                                                         

C_ENGLS	
        ldy #00                                                     
        lda (z80_C),y
        sta Env_Del+1                                               
	sta CurEDel
        iny
        lda (z80_C),y
        sta z80_L                                                   
        sta ESldAdd+1
        iny
        lda (z80_C),y
        sta z80_H                                                   
	sta ESldAdd+9
        clc
        lda z80_C 
        adc #03
        sta z80_C
        bcc sah
        inc z80_B
sah	                                                   
	rts                                                              

C_DELAY	
        ldy #00                 ; lda ($AC,x)	                                         
        lda (z80_C),y
        inc z80_C                                                   
        bne sak
        inc z80_B
sak
	sta Delay+1                                                 
	rts                                                         

SETENV	
        ldy #Env_En                                                 
        lda z80_E
        sta (z80_IX),y
        lda z80_A                ; OPT (inverser et mettre sta AYREGS+EnvTP au début)                                   
        sta AYREGS+EnvTp
	ldy #00                                                     
        lda (z80_C),y           
	sta z80_H                                                   
        sta EnvBase+1                                               
	iny                                                     
        lda (z80_C),y
	sta z80_L                                                   
	sta EnvBase
        lda z80_C
        clc
        adc #02
        sta z80_C
        bcc sam
        inc z80_B                                                 
sam	lda #00                                                     
	ldy #PsInOr                                                 
        sta (z80_IX),y
	sta CurEDel                                                 
	sta z80_H                                                   
        sta CurESld+1                                               
	sta z80_L                                                   
        sta z80_A
	sta CurESld                                                 
C_NOP	
        rts                                                         

SETORN	
        lda z80_A
        asl a                                                         
	sta z80_E                                                   
	lda #00             ; OPT (inutile ?)                                             
        sta z80_D
	ldy #PsInOr                                                 
        sta (z80_IX),y
OrnPtrs
	    lda #$AC           
        clc
        adc z80_E                                           
        sta z80_L
        lda #$AC
        adc #00
        sta z80_H
	ldy #00                                                     
        lda (z80_L),y
MDADDR2
	adc #$AC
        tax             ; save
	iny                                                         
	lda (z80_L),y
        adc #$AC                                               
	    
	ldy #OrnPtr+1                                                 
        sta (z80_IX),y
        dey
	txa                                                   
        sta (z80_IX),y
	rts                                                              

;ALL 16 ADDRESSES TO PROTECT FROM BROKEN PT3 MODULES
SPCCOMS 
        fcw C_NOP-1
	fcw C_GLISS-1
	fcw C_PORTM-1
	fcw C_SMPOS-1
	fcw C_ORPOS-1
	fcw C_VIBRT-1
	fcw C_NOP-1
	fcw C_NOP-1
	fcw C_ENGLS-1
	fcw C_DELAY-1
	fcw C_NOP-1
	fcw C_NOP-1
	fcw C_NOP-1
	fcw C_NOP-1
	fcw C_NOP-1
	fcw C_NOP-1
; ==============================================================================================
CHREGS	
        lda #00                                                  
	    sta z80_A       ; save
        sta Ampl                                                 
	    lda z80_L                                            
        sta val3                                                 
        lda z80_H
        sta val3+1
        ldy #Flags                                               
        lda #%00000001
        sta val1
        lda (z80_IX),y
        bit val1
	    bne saq
        jmp CH_EXIT                                              
saq     	
                                                                 
	    ldy #OrnPtr                                              
        lda (z80_IX),y
        sta z80_L
        sta val1            ; save L
        iny                                                      
        lda (z80_IX),y
        sta z80_H
        sta val1+1          ; save H
	                                                             
        ldy #00
        lda (z80_L),y                                            
        sta z80_E
        iny
        lda (z80_L),y
        sta z80_D
	    ldy #PsInOr                                              
        lda (z80_IX),y
	    sta z80_L                                                
        sta z80_A                                        
	    clc
        lda val1
        adc z80_L
        sta z80_L
        lda val1+1
        adc #00                
        sta z80_H                                               
        lda z80_L
        adc #02
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H
        lda z80_A                                                
        adc #01
        cmp z80_D                                                
	    bcc CH_ORPS                                              
	    clc
        lda z80_E                                                
CH_ORPS	
        ldy #PsInOr                                              
        sta (z80_IX),y
	    ldy #Note                                                
        lda (z80_IX),y
	    ldy #00                                                  
        adc (z80_L),y       ; adc ($AC,x)	
	    bpl CH_NTP                                               
	    lda #00                                                  
CH_NTP	
        cmp #96                                                  
	    bcc CH_NOK                                               
	    lda #95                                                  
CH_NOK	
        asl a                                                      
        sta z80_AP                                               
	    ldy #SamPtr                                              
        lda (z80_IX),y
        sta z80_L
	    sta val1            ; save L
        iny                                                      
        lda (z80_IX),y
        sta z80_H
        sta val1+1          ; save H
	    ldy #00
        lda (z80_L),y                                            
        sta z80_E   
        iny
        lda (z80_L),y
        sta z80_D   

	    ldy #PsInSm                                              
        lda (z80_IX),y
	    sta z80_B                                                
	    asl a                                                      
	    asl a                                                      
	    sta z80_L                                                                                           
        clc
        adc val1
        sta z80_L
        lda val1+1
        adc #00
        sta z80_H                                                     
        lda z80_L
        adc #02
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H

	    lda z80_B                                                                                                      
        adc #01
	    cmp z80_D                                                
	    bcc CH_SMPS                                              
	    lda z80_E                                                
CH_SMPS	
        ldy #PsInSm                                              
        sta (z80_IX),y
        ldy #00
        lda (z80_L),y                                            
        sta z80_C
        iny
        lda (z80_L),y
        sta z80_B

        ldy #TnAcc                                               
        lda (z80_IX),y
        sta z80_E
        iny
        lda (z80_IX),y
	    sta z80_D                                                
	    clc                                                      
        ldy #02
        lda (z80_L),y                                            
        adc z80_E
        tax
        iny
        lda (z80_L),y
        adc z80_D
        sta z80_H
        sta z80_D
        txa
        sta z80_L
        sta z80_E

        lda #%01000000                                           
        bit z80_B
	    beq CH_NOAC                                              
	    ldy #TnAcc                                               
        lda z80_L
        sta (z80_IX),y
	    iny                                                      
        lda z80_H
        sta (z80_IX),y
CH_NOAC 												             
        lda z80_AP                                               
        sta z80_A                                                
        sta z80_L                                                
        clc
        lda #lo(NT_)
        adc z80_L
        sta z80_L
        lda #hi(NT_)
        adc #00
        sta z80_H
        ldy #00
        lda (z80_L),y                                            
        adc z80_E
        tax
        iny
        lda (z80_L),y
        adc z80_D                                               
        sta z80_H
        txa
        sta z80_L
        clc
	    ldy #CrTnSl                                              
        lda (z80_IX),y
        sta z80_E
        adc z80_L
        sta z80_L
	    sta val3
        iny                                                      
        lda (z80_IX),y
        sta z80_D
        adc z80_H
        sta z80_H
        sta val3+1
;CSP_	    
	   
        lda #00                                                  
	    ldy #TSlCnt                                              
        ora (z80_IX),y
	    sta z80_A
        bne saq1                                                 
        jmp CH_AMP
saq1	lda (z80_IX),y                                           
        sec
        sbc #01
        sta (z80_IX),y
	    bne CH_AMP                                               
	    ldy #TnSlDl                                              
        lda (z80_IX),y
        ldy #TSlCnt                                              
        sta (z80_IX),y
	    clc
        ldy #TSlStp                                              
        lda (z80_IX),y
        adc z80_E
        sta z80_L
	    iny                                                      
        lda (z80_IX),y
        adc z80_D
        sta z80_H 
	    sta z80_A       ; save                                   
	    ldy #CrTnSl+1                                              
        sta (z80_IX),y
        dey                                                
        lda z80_L
        sta (z80_IX),y
	    lda #%00000100                                           
        sta val1
        ldy #Flags
        lda (z80_IX),y
        bit val1
	    bne CH_AMP  	                                         
	    ldy #TnDelt                                              
        lda (z80_IX),y
        sta z80_E
	    iny                                                      
        lda (z80_IX),y
        sta z80_D
	lda z80_A                                                
	beq CH_STPP                                              
	lda z80_E												
	ldx z80_L
	sta z80_L
	stx z80_E
	lda z80_D
	ldx z80_H
	sta z80_H
	stx z80_D
CH_STPP
        sec           ; carry = 0 becoze And A                   
        lda z80_L
        sbc z80_E
        sta z80_L
        lda z80_H
        sbc z80_D
        sta z80_H
        bmi CH_AMP                                               
	ldy #SlToNt                                              
        lda (z80_IX),y
	ldy #Note                                                
        sta (z80_IX),y
	lda #00                                                  
	ldy #TSlCnt                                              
        sta (z80_IX),y
	ldy #CrTnSl                                              
        sta (z80_IX),y
        iny                                                      
        sta (z80_IX),y

CH_AMP	
        ldy #CrAmSl                                              
        lda (z80_IX),y
	    sta z80_A       ; save
        lda #%10000000                                           
        bit z80_C
	    beq CH_NOAM                                              
	    lda #%01000000                                           
        bit z80_C
	    beq CH_AMIN                                              
	    lda z80_A                                                
        cmp #15
	    beq CH_NOAM                                              
	    clc                                                      
        adc #01
	    jmp CH_SVAM                                              
CH_AMIN	
        lda z80_A                                                
        cmp #$F1            ; -15
	    beq CH_NOAM                                              
	    sec                                                      
        sbc #01
CH_SVAM	
        ldy #CrAmSl                                              
        sta (z80_IX),y
        sta z80_A
CH_NOAM	
        lda z80_A
        sta z80_L                                                
	    lda z80_B                                                
	    and #15                                                  
	    clc                                                      
        adc z80_L
	    bpl CH_APOS                                              
	    lda #00                                                  
CH_APOS	
        cmp #16                                                  
	    bcc CH_VOL                                               
	    lda #15                                                  
CH_VOL	
        ldy #Volume                                              
        ora (z80_IX),y
	    sta z80_L
        clc                                                
	lda #lo(VT_)                                                
        sta z80_E
        adc z80_L
        sta z80_L
        lda #hi(VT_)
        sta z80_D
        adc #00
        sta z80_H
	    ldy #00                                                  
        lda (z80_L),y       ; lda ($AC,x)	
        sta z80_A       ; save
CH_ENV	
        lda #%00000001                                           
        bit z80_C
	    bne CH_NOEN                                              
	    ldy #Env_En                                              
        lda z80_A
        ora (z80_IX),y
        sta z80_A

CH_NOEN	
        lda z80_A
        sta Ampl                                                 
        lda z80_C                                                
        sta z80_A
        lda #%10000000                                           
        bit z80_B
	    beq NO_ENSL                                              
        lda z80_A
        rol a                                                      
	    rol a                                                      
	    cmp #$80                                                 
        ror a
	    cmp #$80                                                 
        ror a
	    cmp #$80                                                 
        ror a
	    ldy #CrEnSl                                              
        clc
        adc (z80_IX),y
        sta z80_A
        lda #%00100000                                           
        bit z80_B
	    beq NO_ENAC                                              
	    ldy #CrEnSl                                              
        lda z80_A
        sta (z80_IX),y
NO_ENAC	
        lda #lo(AddToEn+1)       ; OPT ?                                    
        sta z80_L
        lda #hi(AddToEn+1)
        sta z80_H
        lda z80_A
        ldy #00                                                  
		                                                         
        clc
        adc (z80_L),y           ; OPT ?
        sta (z80_L),y                                            
	    jmp CH_MIX                                               
NO_ENSL 
        lda z80_A
        ror a                                                      
	    ldy #CrNsSl                                              
        clc
        adc (z80_IX),y
	    sta AddToNs                                              
        sta z80_A       ; save
	    lda #%00100000                                           
        bit z80_B
	    beq CH_MIX                                               
	    ldy #CrNsSl                                              
        lda z80_A
        sta (z80_IX),y
CH_MIX	
        lda z80_B                                                
	    ror a                                                      
	    and #$48                                                 
        sta z80_A
CH_EXIT	
        lda #lo(AYREGS+Mixer)                                     
        sta z80_L
        lda #hi(AYREGS+Mixer)
        sta z80_H
	    lda z80_A
        ldy #00                                                  
        ora (z80_L),y       ; ora ($AC,x)	
	    lsr a                                                      
        bcc saq2
        ora #$80
saq2	sta (z80_L),y                                            
	    lda val3+1                                               
        sta z80_H
        lda val3 
        sta z80_L
	    lda #00                                                  
	    ldy #COnOff                                              
        ora (z80_IX),y
	    sta z80_A       ; save
        bne sas                                                  
        rts
sas 	ldy #COnOff                                              
        lda (z80_IX),y
        sec
        sbc #01
        sta (z80_IX),y
	    beq sat                                                  
        rts
sat 	ldy #Flags                                               
        lda z80_A
        eor (z80_IX),y                                           
        sta (z80_IX),y                                           
	    ror a                                                      
	    ldy #OnOffD                                              
        lda (z80_IX),y
	    bcs CH_ONDL                                              
	    ldy #OffOnD                                              
        lda (z80_IX),y
CH_ONDL	
        ldy #COnOff                                              
        sta (z80_IX),y
        rts                                                         
; ==============================================================================================
PLAY    
        lda #00                                                  
	    sta AddToEn+1                                            
	    sta AYREGS+Mixer                                         
	    lda #$FF                                                 
	    sta AYREGS+EnvTp                                         
	    dec DelyCnt                                              
	    beq sat1                                                 
        jmp PL2
sat1	dec ANtSkCn                                              
	    beq sat2                                                 
        jmp PL1B
AdInPtA
sat2	lda #01                                                  
        sta z80_C
        lda #01
        sta z80_B
	    ldy #00                                                                                                      
        lda (z80_C),y       ; lda ($AC,x)	                                      
	    beq sat3            ; test 0                                                
        jmp PL1A
sat3	sta z80_D                                                
	    sta Ns_Base                                              
	    lda CrPsPtr                                              
        sta z80_L
        lda CrPsPtr+1
        sta z80_H
	    inc z80_L                                                
        bne sar
        inc z80_H
sar                                                     
        lda (z80_L),y                                            
	    clc                                                      
        adc #01
        sta z80_A
        bne PLNLP                                                
	    jsr CHECKLP                                              
LPosPtr
	    lda #$AC                                                 
        sta z80_L
        lda #$AC
        sta z80_H
	    ldy #00                 ; OPT ?                                           
        lda (z80_L),y       ; lda ($AC,x)	                                     
	    clc                                                      
        adc #01
        sta z80_A           ; save
PLNLP	
        lda z80_L                                                
        sta CrPsPtr
        lda z80_H
        sta CrPsPtr+1
	    lda z80_A                                                
        sec
        sbc #01
	    asl a                                                      
	    sta z80_E                                                
        sta z80_A
	    rol z80_D                                                
PatsPtr
	    lda #$AC
        clc
        adc z80_E                                                  
        sta z80_L
        lda #$AC
        adc z80_D
        sta z80_H
	    
	    lda MODADDR+1                                            
        sta z80_E
        lda MODADDR+7
        sta z80_D
                       	                                                             
	    ldy #00                 ; OPT ?
        lda (z80_L),y           ; lda ($AC,x)	                                 
        clc                                                      
        adc z80_E               ; OPT (adc MODADDR+1)
        sta z80_C
        iny
        lda (z80_L),y
        adc z80_D               ; OPT (adc MODADDR+7)
        sta z80_B   
        iny
        lda (z80_L),y                                            
        clc                     ; OPT ?
        adc z80_E               ; IDEM...
        sta AdInPtB+1   
        iny
        lda (z80_L),y
        adc z80_D
        sta AdInPtB+5     
        iny
        lda (z80_L),y                                            
        clc
        adc z80_E               ; IDEM
        sta AdInPtC+1   
        iny
        lda (z80_L),y
        adc z80_D
        sta AdInPtC+5
                                                 
PSP_	

PL1A	
        lda #lo(ChanA)                                              
        sta z80_IX
        lda #hi(ChanA)
        sta z80_IX+1
	jsr PTDECOD                                              
	lda z80_C                                                
        sta AdInPtA+1
        lda z80_B
        sta AdInPtA+5

PL1B	
        dec BNtSkCn                                              
	bne PL1C                                                 
	lda #lo(ChanB)                                              
        sta z80_IX
        lda #hi(ChanB)
        sta z80_IX+1
AdInPtB
	lda #01                                                  
        sta z80_C
        lda #01
        sta z80_B
	jsr PTDECOD                                              
	lda z80_C                                                
        sta AdInPtB+1
        lda z80_B
        sta AdInPtB+5

PL1C	
        dec CNtSkCn                                              
	bne PL1D                                                 
	lda #lo(ChanC)                                              
        sta z80_IX
        lda #hi(ChanC)
        sta z80_IX+1
AdInPtC
	lda #01                                                  
        sta z80_C
        lda #01
        sta z80_B
	jsr PTDECOD                                              
	lda z80_C                                                
        sta AdInPtC+1
        lda z80_B
        sta AdInPtC+5

Delay
PL1D	
        lda #$3E                                                 
	    sta DelyCnt                                              

PL2	
        lda #lo(ChanA)                                              
        sta z80_IX
        lda #hi(ChanA)
        sta z80_IX+1
	    lda AYREGS+TonA                                          
        sta z80_L
        lda AYREGS+TonA+1
        sta z80_H
	    jsr CHREGS                                               
	    lda z80_L                                                
        sta AYREGS+TonA
        lda z80_H
        sta AYREGS+TonA+1
	    lda Ampl                                                 
	    sta AYREGS+AmplA                                         
	
        lda #lo(ChanB)                                              
        sta z80_IX
        lda #hi(ChanB)
        sta z80_IX+1
	    lda AYREGS+TonB                                          
        sta z80_L
        lda AYREGS+TonB+1
        sta z80_H
	    jsr CHREGS                                               
	    lda z80_L                                                
        sta AYREGS+TonB
        lda z80_H
        sta AYREGS+TonB+1
	    lda Ampl                                                 
	    sta AYREGS+AmplB                                         
	    
        lda #lo(ChanC)                                              
        sta z80_IX
        lda #hi(ChanC)
        sta z80_IX+1
	    lda AYREGS+TonC                                          
        sta z80_L
        lda AYREGS+TonC+1
        sta z80_H
	    jsr CHREGS                                               
	    lda z80_L                                                
        sta AYREGS+TonC
        lda z80_H
        sta AYREGS+TonC+1

	    lda Ns_Base_AddToNs                                      
        sta z80_L
        lda Ns_Base_AddToNs+1
        sta z80_H                                              
	    clc                                                      
        adc z80_L
	    sta AYREGS+Noise                                         

AddToEn
	    lda #$3E                                                 
	    sta z80_E                                                
	    asl a                                                      
	    bcc sau                                                  
        lda #$FF
        bne sau1      ; always
sau     lda #00
sau1	sta z80_D                                                
        lda EnvBase+1
        sta z80_H           ; OPT ?
        lda EnvBase                                              
        sta z80_L           ; OPT ?
	    clc                                                      
        adc z80_E
        sta z80_L
        lda z80_D
        adc z80_H           ; OPT ?
        sta z80_H 
        lda CurESld+1
        sta z80_D
        lda CurESld                                              
        sta z80_E
	    clc                                                      
        adc z80_L
        sta AYREGS+Env                                           
        lda z80_D
        adc z80_H
	    sta AYREGS+Env+1                                         

        lda #00                                                  
        ora CurEDel         ; OPT ?                                       
	    beq ROUT                                                 
	    dec CurEDel                                              
	    bne ROUT                                                 
Env_Del
	    lda #$3E                                                 
	    sta CurEDel                                              
ESldAdd
	    lda #$AC                                                 
        clc
        adc z80_E       
        sta CurESld
        lda #$AC
        adc z80_D
	    sta CurESld+1
; ==============================================================================================

ROUT
        ldx AYREGS+1    ; hi ToneA
        lda AYREGS+0    ; lo ToneA
        jsr FIX16BITS
        
        lda #01             
        jsr ay_set
        tya
        tax
        lda #00
        jsr ay_set

        ldx AYREGS+3    ; hi ToneA
        lda AYREGS+2    ; lo ToneA
        jsr FIX16BITS 

        lda #03             
        jsr ay_set
        tya
        tax
        lda #02             
        jsr ay_set

        ldx AYREGS+5    ; hi ToneA
        lda AYREGS+4    ; lo ToneA
        jsr FIX16BITS 

        lda #05             
        jsr ay_set
        tya
        tax
        lda #04             
        jsr ay_set

        lda AYREGS+6    ; data
        ;jsr FIX8BITS
        lsr a             ; /2 
        tax
        lda #06             
        jsr ay_set

        ldx AYREGS+7    ; data
        lda #07
        jsr ay_set

        ldx AYREGS+8    ; data
        lda #08             
        jsr ay_set

        ldx AYREGS+9    ; data
        lda #09             
        jsr ay_set

        ldx AYREGS+10   ; data
        lda #10             
        jsr ay_set

        ldx AYREGS+12   ; hi Env
        lda AYREGS+11   ; lo Env
        jsr FIX16BITS 

        lda #12             
        jsr ay_set
        tya
        tax
        lda #11             
        jsr ay_set

        ; shunte R13 si $FF (Y=13) => plus généralement >=$80
        ldx AYREGS+13
        bmi FIN_RTS
        lda #13
        jsr ay_set
FIN_RTS
        rts
; -------------------------------------
FIX16BITS       ; INT(256*2*1000/1773) = 289 = 256 + 32 + 1
                ; IN:  register A is low byte
                ;      register X is high byte
                ; OUT: register Y is low byte
                ;      register X is high byte

        ; x256
        stx TA1
        sta TB1
        stx TB2
        sta TC2
        stx TB3
        sta TC3
        lda #00
        sta TA2
        
        ; x32
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        
        ; x32 + x01
        clc
        lda TC3
        adc TC2
        ; sta TC2
        lda TB3
        adc TB2
        sta TB2
        lda TA2
        adc #00
        sta TA2

        ; + x256 
        clc         
        lda TB2
        adc TB1
        tay         ; sta TB1
        lda TA2
        adc TA1
        ; sta TA1

        ; / 2 (16bits)
        lsr a         ; lsr TA1
        tax         ; ldx TA1
        tya         ; lda TB1     
        ror a         ; ror TB1
        tay         ; ldy TB1
        rts 

; HB-BBC-128 settings:
;* AY-3-8910 definitions
;* The sound chip is accessed through VIA 2
IO_1		= 0x0480
PRB		= 0x00
PRA		= 0x01
DDRB		= 0x02
DDRA		= 0x03
SND_ADBUS	= IO_1+PRA
SND_MODE	= IO_1+PRB

SND_SELREAD		= 0x40
SND_SELWRITE		= 0x02
SND_SELSETADDR		= (SND_SELREAD|SND_SELWRITE)
SND_DESELECT_MASK	= (0xff-SND_SELREAD-SND_SELWRITE)


;****************************************
;* ay_set
;* Set AY register A to value X
;* Input : A = Reg no, X = Value
;* Output : None
;* Regs affected : None
;****************************************
ay_set
        pha

	lda #0xff			; Set Port A to output
	sta IO_1 + DDRA

        pla
	sta SND_ADBUS			; Put A on the sound bus (A = reg address)

	lda SND_MODE			; Need to preserve contents of other bits
	and #SND_DESELECT_MASK	        ; Mask off mode bits
	ora #SND_SELSETADDR		; Select AY mode to latch address
	sta SND_MODE			; This write will process the data in ADBUS according to SND_MODE

	and #SND_DESELECT_MASK	        ; Mask off mode bits
	sta SND_MODE			; This write will deselect the AY ready for next command
	
	stx SND_ADBUS			; Put X on the sound bus (X = value)
	ora #SND_SELWRITE		; Select mode for writing data
	sta SND_MODE			; This write will process the data in ADBUS according to SND_MODE
	
	and #SND_DESELECT_MASK	        ; Mask off mode bits
	sta SND_MODE			; This write will deselect the AY ready for next command

	rts

; =============================================================================
NT_DATA	
        fcb (T_NEW_0-T1_)*2
	    fcb TCNEW_0-T_
	    fcb (T_OLD_0-T1_)*2+1
	    fcb TCOLD_0-T_
	    fcb (T_NEW_1-T1_)*2+1
	    fcb TCNEW_1-T_
	    fcb (T_OLD_1-T1_)*2+1
	    fcb TCOLD_1-T_
	    fcb (T_NEW_2-T1_)*2
	    fcb TCNEW_2-T_
	    fcb (T_OLD_2-T1_)*2
	    fcb TCOLD_2-T_
	    fcb (T_NEW_3-T1_)*2
	    fcb TCNEW_3-T_
	    fcb (T_OLD_3-T1_)*2
	    fcb TCOLD_3-T_

T_

TCOLD_0	fcb $00+1,$04+1,$08+1,$0A+1,$0C+1,$0E+1,$12+1,$14+1
	    fcb $18+1,$24+1,$3C+1,0
TCOLD_1	fcb $5C+1,0
TCOLD_2	fcb $30+1,$36+1,$4C+1,$52+1,$5E+1,$70+1,$82,$8C,$9C
	    fcb $9E,$A0,$A6,$A8,$AA,$AC,$AE,$AE,0
TCNEW_3	fcb $56+1
TCOLD_3	fcb $1E+1,$22+1,$24+1,$28+1,$2C+1,$2E+1,$32+1,$BE+1,0
TCNEW_0	fcb $1C+1,$20+1,$22+1,$26+1,$2A+1,$2C+1,$30+1,$54+1
	    fcb $BC+1,$BE+1,0
TCNEW_1 = TCOLD_1
TCNEW_2	fcb $1A+1,$20+1,$24+1,$28+1,$2A+1,$3A+1,$4C+1,$5E+1
	    fcb $BA+1,$BC+1,$BE+1,0

EMPTYSAMORN = *-1
	    fcb 1,0,$90 ;delete #90 if you don't need default sample

;first 12 values of tone tables

T1_ 	
        fcw $1DF0
        fcw $1C20
        fcw $1AC0
        fcw $1900
        fcw $17B0
        fcw $1650
        fcw $1510
        fcw $13E0

        fcw $12C0
        fcw $11C0
        fcw $10B0
        fcw $0FC0
        fcw $1A7C
        fcw $1900
        fcw $1798
        fcw $1644

        fcw $1504
        fcw $13D8
        fcw $12B8
        fcw $11AC
        fcw $10B0
        fcw $0FC0
        fcw $0EDC
        fcw $0E08

        fcw $19B4
        fcw $1844
        fcw $16E6
        fcw $159E
        fcw $1466
        fcw $1342
        fcw $122E
        fcw $1128

        fcw $1032
        fcw $0F48
        fcw $0E6E
        fcw $0D9E
        fcw $0CDA
        fcw $1A20
        fcw $18AA
        fcw $1748

        fcw $15F8
        fcw $14BE
        fcw $1394
        fcw $127A
        fcw $1170
        fcw $1076
        fcw $0F8A
        fcw $0EAA

        fcw $0DD8

T_OLD_1	= T1_
T_OLD_2	= T_OLD_1+24
T_OLD_3	= T_OLD_2+24
T_OLD_0	= T_OLD_3+2
T_NEW_0	= T_OLD_0
T_NEW_1	= T_OLD_1
T_NEW_2	= T_NEW_0+24
T_NEW_3	= T_OLD_3

FILE_END =*
; ===========================

.bss        ; uninitialized data stuff

;vars from here can be stripped
;you can move VARS to any other address

VARS
;ChannelsVars

; STRUCT "CHP"
PsInOr	= 0
PsInSm	= 1
CrAmSl  = 2
CrNsSl	= 3
CrEnSl	= 4
TSlCnt	= 5
CrTnSl	= 6
TnAcc	= 8
COnOff	= 10
OnOffD	= 11
OffOnD	= 12
OrnPtr	= 13
SamPtr	= 15
NNtSkp	= 17
Note	= 18
SlToNt	= 19
Env_En	= 20
Flags	= 21
TnSlDl	= 22
TSlStp	= 23
TnDelt	= 25
NtSkCn	= 27
Volume	= 28
; end STRUCT

; CHANNEL A
ChanA	
;reset group
APsInOr	fcb 0
APsInSm	fcb 0
ACrAmSl	fcb 0
ACrNsSl	fcb 0
ACrEnSl	fcb 0
ATSlCnt	fcb 0
ACrTnSl	fcw 0
ATnAcc	fcw 0
ACOnOff	fcb 0
;reset group

AOnOffD	fcb 0

AOffOnD	fcb 0
AOrnPtr	fcw 0
ASamPtr	fcw 0
ANNtSkp	fcb 0
ANote	fcb 0
ASlToNt	fcb 0
AEnv_En	fcb 0
AFlags	fcb 0
 ;Enabled - 0,SimpleGliss - 2
ATnSlDl	fcb 0
ATSlStp	fcw 0
ATnDelt	fcw 0
ANtSkCn	fcb 0
AVolume	fcb 0
	
; CHANNEL B
ChanB
;reset group
BPsInOr	fcb 0
BPsInSm	fcb 0
BCrAmSl	fcb 0
BCrNsSl	fcb 0
BCrEnSl	fcb 0
BTSlCnt	fcb 0
BCrTnSl	fcw 0
BTnAcc	fcw 0
BCOnOff	fcb 0
;reset group

BOnOffD	fcb 0

BOffOnD	fcb 0
BOrnPtr	fcw 0
BSamPtr	fcw 0
BNNtSkp	fcb 0
BNote	fcb 0
BSlToNt	fcb 0
BEnv_En	fcb 0
BFlags	fcb 0
 ;Enabled - 0,SimpleGliss - 2
BTnSlDl	fcb 0
BTSlStp	fcw 0
BTnDelt	fcw 0
BNtSkCn	fcb 0
BVolume	fcb 0

; CHANNEL C
ChanC
;reset group
CPsInOr	fcb 0
CPsInSm	fcb 0
CCrAmSl	fcb 0
CCrNsSl	fcb 0
CCrEnSl	fcb 0
CTSlCnt	fcb 0
CCrTnSl	fcw 0
CTnAcc	fcw 0
CCOnOff	fcb 0
;reset group

COnOffD	fcb 0

COffOnD	fcb 0
COrnPtr	fcw 0
CSamPtr	fcw 0
CNNtSkp	fcb 0
CNote	fcb 0
CSlToNt	fcb 0
CEnv_En	fcb 0
CFlags	fcb 0
 ;Enabled - 0,SimpleGliss - 2
CTnSlDl	fcb 0
CTSlStp	fcw 0
CTnDelt	fcw 0
CNtSkCn	fcb 0
CVolume	fcb 0

; ------------

;GlobalVars
DelyCnt	fcb 0
CurESld	fcw 0
CurEDel	fcb 0
Ns_Base_AddToNs
Ns_Base	fcb 0
AddToNs	fcb 0

; ===========================
AYREGS ; AY registers

TonA	= 0
TonB	= 2
TonC	= 4
Noise	= 6
Mixer	= 7
AmplA	= 8
AmplB	= 9
AmplC	= 10
Env	    = 11
EnvTp	= 13
; ---

Ampl	= AYREGS+AmplC
; ===========================
VT_	ds 256 ;CreatedVolumeTableAddress

EnvBase	= VT_+14
VAR0END	= VT_+16 ;INIT zeroes from VARS to VAR0END-1

; ===========================
NT_	ds 192 ;CreatedNoteTableAddress

VARS_END = *
PT3END
