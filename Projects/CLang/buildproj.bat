::@ECHO OFF

::
:: Initial check.
:: Verify if the SDK is correctly configurated
::
IF "%HBSDK%"=="" GOTO ErCfg

echo %HBSDK%

del hellobin
::
:: Launch the compilation of files
::
CALL %HBSDK%\bin\cc65 --cpu 65sc02 -O hello.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 hello.s

CALL %HBSDK%\bin\ld65 -C HB128\dolo128.cfg -vm -m hello.map -o hellobin hello.o HB128\sbc.lib

CALL imdisk -a -o rem -t file -m F: -f ..\..\emu\software\filesystem\sdcard64m.img -v 1
copy hellobin f:\hello1
::dir f:
CALL imdisk -D -m F:

GOTO End


::
:: Outputs an error message
::
:ErCfg
ECHO == ERROR ==
ECHO The Homebrew SDK was not configured properly
ECHO You should have a HBSDK environment variable setted to the location of the SDK
IF "%OSDKBRIEF%"=="" PAUSE
GOTO End


:End
