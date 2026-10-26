.include "../hb128/hb128.inc"

MAPROWCOUNT=10

.export _renderViewAsm

.importzp ptr1,ptr2,ptr3,ptr4,tmp1,tmp2,tmp3,tmp4
.import _tileDef, _superTileDef, _superTileMap, _tileCombos
.import _mapX, _mapS, _scrBuf,_laser_name,_scroll
.import _maxstars,_staridxl,_staridxh,_staryoff,_starpat


.segment "BSS"
mapRowCount:
    .res 1
scrIndex:
    .res 1
mapIndex:
    .res 1

.segment  "CODE"

; Given two tile indexes in tmp3,4
; Get right pattern tile with scroll value in _mapS
getPatternName:
    lda tmp4                    ; Get second tile
    asl a                       ; x16
    asl a
    asl a
    asl a
    ora tmp3                    ; Or in first tile
    tay                         ; We have the index
    lda _tileCombos,y           ; Get the base pattern
    adc _mapS                   ; Add scroll offset
    rts

; Do even map offset supertile decoding
doEvenOffset:
    ; Get top-left tile from supertile 1 into tmp3
    ldy tmp1
    lda _superTileDef,y
    sta tmp3
    ; Get adjacent tile from same supertile into tmp4
    lda _superTileDef+1,y
    sta tmp4
    jsr getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr3),y

    ; Get top-right tile into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get adject tile from next supertile into tmp4
    ldy tmp2
    lda _superTileDef,y
    sta tmp4
    jsr getPatternName          ; Get pattern for top-left
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
    jsr getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr4),y

    ; Get bottom-right tile into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get adject tile from next supertile into tmp4
    ldy tmp2
    lda _superTileDef+2,y
    sta tmp4
    jsr getPatternName          ; Get pattern for top-left
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
    jsr getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr3),y

    ; Get top-left tile of supertile 2 into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get adject top-right tile from supertile 2 into tmp4
    ldy tmp2
    lda _superTileDef+1,y
    sta tmp4
    jsr getPatternName          ; Get pattern for top-left
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
    jsr getPatternName          ; Get pattern for top-left
    ldy scrIndex
    sta (ptr4),y

    ; Get bottom-left tile of supertile 2 into tmp3 (already in tmp4)
    lda tmp4
    sta tmp3
    ; Get bottom-right tile from same supertile into tmp4
    ldy tmp2
    lda _superTileDef+3,y
    sta tmp4
    jsr getPatternName          ; Get pattern for top-left
    ldy scrIndex
    iny
    sta (ptr4),y
    rts

; This is the place to jsr for processing odd or even
doOddorEvenOffset:
    jmp $0000


; Render view using _mapX (0..255), _mapS (0..3)
_renderViewAsm:
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
    lsr _mapX
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
    lda _mapX                   ; Start at X offset into map
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
    tya                         ; But only lower 7 bits
    and #$7f
    tay
    lda (ptr1),y
    asl a
    asl a
    sta tmp2
    ; Use the current index
    ldy mapIndex
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
    lda ptr1+1
    adc #0
    sta ptr1+1

    ; Increment scrBuf pointers by 64 (2 screen rows)
    clc
    lda ptr3
    adc #64
    sta ptr3
    lda ptr3+1
    adc #0
    sta ptr3+1
    lda ptr4
    adc #64
    sta ptr4
    lda ptr4+1
    adc #0
    sta ptr4+1

    dec mapRowCount             ; Count down map tiles to go
    bne renderYLoop             ; Still more rows to do

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
    sta tmp2
    lda #3
    sec
    sbc tmp2
    sta tmp2

    pla
    lsr a
    lsr a
    sta tmp3                    ; Screen offset 0..31

    ldx _maxstars               ; Put some stars on
starLoop:
    clc
    lda _staridxl-1,x
    adc #<_scrBuf
    sta tmp4
    lda _staridxh-1,x
    adc #>_scrBuf
    sta tmp4+1
    lda _staryoff-1,x
    sec
    sbc tmp3
    bcc nowrap
    adc #31
nowrap:
    and #31
    tay
    lda (tmp4),y
    cmp #132
    bcs nextStar
    lda _starpat-1,x
    clc
    adc tmp2
    sta (tmp4),y
nextStar:
    dex
    bne starLoop

    rts
