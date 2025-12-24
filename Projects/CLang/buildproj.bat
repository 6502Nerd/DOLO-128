::@ECHO OFF

::
:: Initial check.
:: Verify if the SDK is correctly configurated
::
IF "%HBSDK%"=="" GOTO ErCfg

echo %HBSDK%

::
:: Launch the compilation of files
::
CALL %HBSDK%\bin\cc65 --cpu 65sc02 -O hello.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 hello.s

CALL %HBSDK%\bin\ld65 -C HB128\dolo128.cfg -vm -m hello.map -o hellobin hello.o HB128\sbc.lib

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
