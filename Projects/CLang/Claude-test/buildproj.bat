::@ECHO OFF

::
:: Initial check.
:: Verify if the SDK is correctly configurated
::
IF "%HBSDK%"=="" GOTO ErCfg

echo %HBSDK%

if exist tank.bin del tank.bin
::
:: Launch the compilation of files
::
CALL %HBSDK%\bin\cc65 --cpu 65sc02 -Oirs tank.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 tank.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 gfx.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 math.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 xform.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 input.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 sound.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 tables.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 font.s

CALL %HBSDK%\bin\ld65 -C tank.cfg -vm -m tank.map -o tank.bin tank.o gfx.o math.o xform.o input.o sound.o tables.o font.o ..\HB128\sbc.lib

:: "buildproj nodeploy" just builds without copying to the SD card image
IF /I "%1"=="nodeploy" GOTO End

CALL imdisk -a -o rem -t file -m F: -f ..\..\..\emu\software\filesystem\sdcard64m.img -v 1
if not exist f:\games\tank mkdir f:\games\tank
copy tank.bin f:\games\tank

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
