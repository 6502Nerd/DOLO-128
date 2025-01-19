; PT3 player in dflat!
; 2025
def_start()
 dim code[100]
 println "Ensure PT3 player is loaded in 0x8000"
 println "Ensure PT3 tune is loaded somewhere"
 _asm(0):_asm(0):_asm(2)
 println "a=call(start,songLo,songHi,0)"
 println "Call mute, stop"
 enddef
 ;
 ;
 def_asm(o)
  .opt o
  .org code
  ; Now VIA int is on the NMI line!
  userIrq=12
  pt3init=0x8000
  pt3play=pt3init+7
  pt3mute=pt3init+10
  via1=0x480
  .intCount
  .ds 1
  .oldIrq
  .ds 2
  ; Initialise player to run on nmi
  .start
  php:sei
  ; A,X provides song address
  jsr pt3init
  ; Remember previous user irq
  lda userIrq:sta oldIrq
  lda userIrq+1:sta oldIrq+1
  ; Instate PT3 irq
  lda #pt3Irq&0xff:sta userIrq
  lda #pt3Irq>>8:sta userIrq+1
  ; Set up timer for 50ms interrupts
  ; @5.36MHz it is 107,200 cycles
  ; which doesn't fit into 16 bit!;
  ; so instead set up 25ms interrupts
  ; which is 53,600 cycles, but only
  ; invoke the sound player every other
  ; interrupt!
  ; 53,600 = 0xd160
  lda #0x60
  sta via1+4
  lda #0xd1
  sta via1+5
  ; T1 of VIA1 set to continuous
  lda #0b01000000
  sta via1+11
  ; Enable T1 interrupt
  lda #0b11000000
  sta via1+14
  ; Restore P (enables interrupts)
  plp
  rts
  ;
  ; Call pt3 player every interrupt
  .pt3Irq
  ; Reset interrupt by reading T1C-L
  lda via1+4
  ; Call player every other interrupt
  lda #0x80
  eor intCount
  sta intCount
  bpl skipInt 
  ; Call the player each tick
  jsr pt3play
  .skipInt
  rts
  ; mute player
  .mute
  jsr pt3mute
  rts
  ; stop player
  .stop
  php:sei
  ; Disable T1 interrupt
  lda #0b01000000
  sta via1+14
  ; Restore previous irq
  lda oldIrq:sta userIrq
  lda oldIrq+1:sta userIrq+1
  ; Restore P (enables interrupts)
  plp
  rts
enddef
;
println "Check instructions!"
