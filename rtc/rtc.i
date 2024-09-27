;**********************************************************
;*
;*	BBC-128 HOMEBREW COMPUTER
;*	Hardware and software design by @6502Nerd (Dolo Miah)
;*	Copyright 2014-20
;*  Free to use for any non-commercial purpose subject to
;*  appropriate credit of my authorship please!
;*
;*  RTC.I
;*  Definitions file for the RTC module.  The key structure
;*  used by the real time clock is defined here.
;*  It is a DS1288
;*
;**********************************************************

RTC_SEC		= 0x00
RTC_SECA	= 0x01
RTC_MIN		= 0x02
RTC_MINA	= 0x03
RTC_HR		= 0x04
RTC_HRA		= 0x05
RTC_DOW		= 0x06
RTC_DAY		= 0x07
RTC_MTH		= 0x08
RTC_YR		= 0x09
RTC_REGA	= 0x0a
RTC_REGB	= 0x0b
RTC_REGC	= 0x0c
RTC_REGD	= 0x0d

RTC_UIP		= 0x80
RTC_DV2		= 0x40
RTC_DV1		= 0x20
RTC_DV0		= 0x10
RTC_RS3		= 0x80
RTC_RS2		= 0x40
RTC_RS1		= 0x20
RTC_RS0		= 0x10

RTC_SET		= 0x80
RTC_PIE		= 0x40
RTC_AIE		= 0x20
RTC_UIE		= 0x10
RTC_SQWE	= 0x80
RTC_DM		= 0x04
RTC_2412	= 0x02
RTC_DSE		= 0x01

RTC_IRQF	= 0x80
RTC_PF		= 0x40
RTC_AF		= 0x20
RTC_UF		= 0x10

RTC_VRT		= 0x80

RTC_ADDR	= 0x600
RTC_DATA	= 0x601

NV_MODE     = 0x0e          ; Default boot up screen mode
NV_COLOUR   = 0x0f          ; Default boot up colour

NV_RAMSZ    = 63            ; Checksum byte in NV ram.  127 in real hardware but 63 for compatibility with MAME emulation.