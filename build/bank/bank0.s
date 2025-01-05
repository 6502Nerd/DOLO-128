_bank0_start=0xc000
	include "kernel\kernel.s"

; Bank specific code goes here
	include "monitor\cmd.s"
	include "cia\cia.s"
	include "serial\serial.s"
	include "keyboard\keyboard.s"
	include "rtc\rtc.s"
	include "sound\sound.s"
	include "vdp\vdp.s"
	include "vdp\graph.s"
	; End of Code
_code_end
_bank0_end
