::@ECHO OFF

::
:: Initial check.
:: Verify if the SDK is correctly configurated
::
IF "%HBSDK%"=="" GOTO ErCfg

echo %HBSDK%

del may4.bin
::
:: Launch the compilation of files
::
CALL %HBSDK%\bin\cc65 --cpu 65sc02 -O may4.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 may4.s

CALL %HBSDK%\bin\ca65 --cpu 65sc02 data.s

::CALL %OSDK%\bin\bin2txt -s1 -f2 -h1 -n16 retro-fest-msx scrn.s _scrn:
::CALL %HBSDK%\bin\ca65 --cpu 65sc02 scrn.s

CALL %HBSDK%\bin\ld65 -C ..\HB128\dolo128.cfg -vm -m may4.map -o may4.bin may4.o data.o ..\HB128\sbc.lib

CALL imdisk -a -o rem -t file -m F: -f ..\..\..\emu\software\filesystem\sdcard64m.img -v 1
copy may4.bin f:\demos\may4
copy may4 f:\demos\may4
copy starwars.pt3 f:\demos\may4

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
