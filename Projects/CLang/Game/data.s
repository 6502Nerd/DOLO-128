.export _tileDef, _superTileDef, _superTileMap, _x_coord, _y_coord, _spritePattern

.segment  "DATA"

_tileDef:
.incbin   "assets/tiles_SC4Tiles.bin"

_superTileDef:
.incbin   "assets/tiles_SC4Super.bin"

_superTileMap:
.incbin   "assets/tiles_SC4Map.bin"

.include  "sprite_table.s"

_spritePattern:
; Sprite sprite_1 pattern 1
   .byte $00,$00,$C0,$60,$90,$9F,$6F,$3F,$1F,$0F,$0F,$07,$01,$01,$00,$00
   .byte $C0,$00,$00,$C0,$C0,$F8,$20,$20,$A0,$FF,$FF,$FE,$10,$10,$00,$00
; Sprite sprite_1 pattern 2
   .byte $00,$0F,$0F,$90,$60,$60,$90,$00,$00,$00,$00,$00,$00,$00,$1F,$1F
   .byte $00,$FC,$FC,$00,$00,$00,$DE,$DF,$5F,$00,$00,$00,$00,$02,$FE,$FC
