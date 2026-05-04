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
CALL %HBSDK%\bin\cc65 --cpu 65sc02 -O fest26.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 fest26.s

CALL %HBSDK%\bin\ca65 --cpu 65sc02 data.s

::CALL %OSDK%\bin\bin2txt -s1 -f2 -h1 -n16 retro-fest-msx scrn.s _scrn:
::CALL %HBSDK%\bin\ca65 --cpu 65sc02 scrn.s

CALL %HBSDK%\bin\ld65 -C ..\HB128\dolo128.cfg -vm -m fest26.map -o fest26.bin fest26.o data.o ..\HB128\sbc.lib

CALL imdisk -a -o rem -t file -m F: -f ..\..\..\emu\software\filesystem\sdcard64m.img -v 1
copy fest26.bin f:\demos\fest26
copy fest26.sc2 f:\demos\fest26
copy ahatake.pt3 f:\demos\fest26

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
