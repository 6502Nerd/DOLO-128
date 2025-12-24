::@ECHO OFF

::
:: Initial check.
:: Verify if the SDK is correctly configurated
::
IF "%HBSDK%"=="" GOTO ErCfg

echo %HBSDK%

::
:: Set the build paremeters
::
:: CALL hbsdk_config.bat

::
:: Launch the compilation of library and runtime
::
:: Using Atmos as the base library
copy %HBSDK%\lib\atmos.lib sbc.lib

:: Compile / Assemble the runtime objects
CALL %HBSDK%\bin\ca65 --cpu 65sc02 crt0.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 read.s
CALL %HBSDK%\bin\ca65 --cpu 65sc02 hbputc.s

CALL %HBSDK%\bin\cc65 --cpu 65sc02 -O write.c
CALL %HBSDK%\bin\ca65 --cpu 65sc02 write.s

:: Create the final library
CALL %HBSDK%\bin\ar65 r sbc.lib crt0.o read.o write.o hbputc.o

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
