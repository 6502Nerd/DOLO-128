.include "../hb128/hb128.inc"

MAPROWCOUNT=10

.export _renderViewAsm

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import _tileDef, _superTileDef, _superTileMap, _tileCombos
.import _mapX, _mapS, _scrBuf,_laser_name,_scroll
.import _maxstars,_staridxl,_staridxh,_staryoff,_starpat
.import _scrBufOffL,_scrBufOffH

.segment "DATA"
tile_high:
    .byte $00,$10,$20,$30,$40,$50,$60,$70,$80,$90,$a0,$b0,$c0,$d0,$e0,$f0
scroll_value:
    .byte 3,2,1,0

mapS=ptr2
scrIndex=ptr2+1

.segment "BSS"
mapRowCount:
    .res 1
mapIndex:
    .res 1
mapX:
    .res 1

.segment  "CODE"

; Given two tile indexes in tmp3,4
; Get right pattern tile with scroll value in _mapS
.macro getPatternName
    tay                         ; From A, get second tile as high nibble
    lda tile_high,y
    ora tmp3                    ; Or in first tile
    tay                         ; We have the index
    lda _tileCombos,y           ; Get the base pattern
    ora mapS                    ; Or in the scroll offset 0..3
.endmacro

; Do even map offset supertile decoding
doEvenOffset:
    ; Get top-left tile from supertile 1 into tmp3
    ldy tmp1
    lda _superTileDef,y
    sta tmp3
    ; Get adjacent tile from same supertile into tmp4
    lda _superTileDef+1,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr3),y

    ; Get top-right tile into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get adject tile from next supertile into tmp4
    ldy tmp2
    lda _superTileDef,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    iny
    sta (ptr3),y

    ; Get bottom-left tile from supertile 1 into tmp3
    ldy tmp1
    lda _superTileDef+2,y
    sta tmp3
    ; Get adjacent tile from same supertile into tmp4
    lda _superTileDef+3,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr4),y

    ; Get bottom-right tile into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get adject tile from next supertile into tmp4
    ldy tmp2
    lda _superTileDef+2,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    iny
    sta (ptr4),y
    rts

; Do odd map offset supertile decoding
doOddOffset:
    ; Get top-right tile from supertile 1 into tmp3
    ldy tmp1
    lda _superTileDef+1,y
    sta tmp3
    ; Get adjacent tile from next supertile into tmp4
    ldy tmp2
    lda _superTileDef,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr3),y

    ; Get top-left tile of supertile 2 into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get adject top-right tile from supertile 2 into tmp4
    ldy tmp2
    lda _superTileDef+1,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    iny
    sta (ptr3),y

    ; Get bottom-right tile from supertile 1 into tmp3
    ldy tmp1
    lda _superTileDef+3,y
    sta tmp3
    ; Get bottom-left tile from supertile 2 into tmp4
    ldy tmp2
    lda _superTileDef+2,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr4),y

    ; Get bottom-left tile of supertile 2 into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get bottom-right tile from same supertile into tmp4
    ldy tmp2
    lda _superTileDef+3,y
    sta tmp4
    getPatternName          ; Get pattern for top-left
    ldy scrIndex
    iny
    sta (ptr4),y
    rts

; This is the place to jsr for processing odd or even
doOddorEvenOffset:
    jmp $0000


; Render view using _mapX (0..255), _mapS (0..3)
_renderViewAsm:
    lda _mapS           ; Cache in zero page
    sta mapS
    ; Supertile map start adddress
    lda #<_superTileMap
    sta ptr1
    lda #>_superTileMap
    sta ptr1+1

    ; Assume even offset
    lda #<doEvenOffset
    sta doOddorEvenOffset+1
    lda #>doEvenOffset
    sta doOddorEvenOffset+2

    ; _mapX needs to normalised to supertile index div 2
    lda _mapX
    lsr a
    sta mapX
    ; If C then it's an odd offset
    bcc skipOddOffset
    lda #<doOddOffset
    sta doOddorEvenOffset+1
    lda #>doOddOffset
    sta doOddorEvenOffset+2
skipOddOffset:
    ; Screen buffer pointers for current and next row
    lda #<_scrBuf
    sta ptr3
    lda #>_scrBuf
    sta ptr3+1
    lda #<(_scrBuf+32)
    sta ptr4
    lda #>(_scrBuf+32)
    sta ptr4+1
    lda #MAPROWCOUNT            ; Number of supertile rows in map
    sta mapRowCount
renderYLoop:
    stz scrIndex                ; Index into screen
    lda mapX                   ; Start at X offset into map
    sta mapIndex
    ldx #0
renderXLoop:
    ; Get adjacent supertiles from map, index by Y
    ; result in tmp1 and tmp2
    ldy mapIndex
    lda (ptr1),y
    asl a
    asl a
    sta tmp1
    iny                         ; Point to next supertile
    bpl skip_reset              ; But only lower 7 bits
    ldy #0
skip_reset:
    lda (ptr1),y
    asl a
    asl a
    sta tmp2
    ; process the tiles for one supertile row (2 screen rows)
    jsr doOddorEvenOffset

    ; Do next supertile
    lda mapIndex
    inc a
    and #$7f
    sta mapIndex
    ; Advance screen index by 2
    inx
    inx
    stx scrIndex

    cpx #32                     ; Done a whole row?
    bne renderXLoop             ; Nope go again with next tile

    ; Increment map pointer
    clc
    lda ptr1
    adc #128
    sta ptr1
    bcc skip_maph
    inc ptr1+1
skip_maph:
    ; Increment scrBuf pointers by 64 (2 screen rows)
    clc
    lda ptr3
    adc #64
    sta ptr3
    bcc skip_scrbuf1
    inc ptr3+1
skip_scrbuf1:
    clc
    lda ptr4
    adc #64
    sta ptr4
    bcc skip_scrbuf2
    inc ptr4+1
skip_scrbuf2:

    dec mapRowCount             ; Count down map tiles to go
    bne renderYLoop             ; Still more rows to do

    ; Set up for plotting stars
    
    lda _scroll+1               ; Map 1024->128 positions (divide by 8)
    sta tmp3
    lda _scroll
    lsr tmp3
    ror a
    lsr tmp3                    ; no more high byte bits left
    ror a
    lsr a                       ; Value between 0..128
    pha

    ; Calc scroll value 0..3
    and #3
    tax
    lda scroll_value,x
    sta tmp2

    pla
    lsr a
    lsr a
    sta tmp3                    ; Screen offset 0..31

    ldx _maxstars               ; Put some stars on
starLoop:
    lda _staridxl-1,x
    sta ptr1
    lda _staridxh-1,x
    sta ptr1+1
    lda _staryoff-1,x
    sec
    sbc tmp3
    and #31
    tay
    lda (ptr1),y
    cmp #132
    bcs nextStar
    lda _starpat-1,x
    clc
    adc tmp2
    sta (ptr1),y
nextStar:
    dex
    bne starLoop

    rts
