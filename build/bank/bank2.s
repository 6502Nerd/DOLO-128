_bank2_start=0xc000
	include "kernel\kernel.s"
	
; Bank specific code goes here
	include "sdcard\sdcard.s"
	include "sdcard\sd_fs.s"

	; End of Code
_code_end
_bank2_end
	
