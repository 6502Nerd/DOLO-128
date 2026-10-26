::@ECHO OFF

::
:: Initial check.
:: Verify if the SDK is correctly configurated
::
IF "%HBSDK%"=="" GOTO ErCfg

::
:: Launch the compilation of files
::
CALL python tables.py > tables.s
CALL %HBSDK%\bin\cc65 --cpu 65sc02 -O game.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 game.s

CALL %HBSDK%\bin\ca65 --cpu 65sc02 data.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 vbint.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 engine.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 player.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 laser.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 sprite.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 foe.s

CALL %HBSDK%\bin\ld65 -C ..\HB128\dolo128.cfg -vm -m game.map -o game.bin game.o player.o foe.o laser.o sprite.o data.o vbint.o engine.o ..\HB128\sbc.lib

CALL imdisk -a -o rem -t file -m F: -f ..\..\..\emu\software\filesystem\sdcard64m.img -v 1 > nul
mkdir f:\demos\game
copy game.bin f:\demos\game

::dir f:
CALL imdisk -D -m F: > nul

GOTO End


::
:: Outputs an error message
::
:ErCfg
ECHO == ERROR ==
ECHO The Homebrew SDK was not configured properly
ECHO You should have a HBSDK environment variable setted to the location of the SDK


:End
