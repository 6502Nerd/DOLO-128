_bank1_start=0xc000
	include "kernel\kernel.s"
	
; Bank specific code goes here
	include "utils\intmath.s"
	include "dflat\dflat.s"
	include "dflat\error.s"
	include	"dflat\asm.s"

	; End of Code
_code_end
_bank1_end
	
