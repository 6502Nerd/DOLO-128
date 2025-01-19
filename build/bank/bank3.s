_bank0_start=0xc000
	include "kernel\kernel.s"

; Bank specific code goes here
	include "sound\ptplayer.s"

	; End of Code
_code_end
_bank3_end
