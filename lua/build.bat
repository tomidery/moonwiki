@echo off
REM If you don't want to use make, run this script.
REM But make sure you read config to see what can be customized.

REM configuration for MinGW:
SET MINGW_HOME=c:\MinGW
SET CC=%MINGW_HOME%\bin\mingw32-gcc.exe
SET AR=%MINGW_HOME%\bin\ar.exe
SET RANLIB=%MINGW_HOME%\bin\ranlib.exe
SET STRIP=%MINGW_HOME%\bin\strip.exe
SET CFLAGS=-O2 -Wall -DLUA_USER_H="""../etc/luser_number.h""" -DUSE_FASTROUND

REM Easiest way to build Lua libraries and executables:
echo building core library...
cd src
%CC% %CFLAGS% -c -I..\include *.c
%AR% rc ..\lib\liblua.a *.o
%RANLIB% ..\lib\liblua.a
del *.o

echo standard library...
cd lib
%CC% %CFLAGS% -DUSE_POPEN=1 -Dpopen=_popen -Dpclose=_pclose -c -I..\..\include *.c
%AR% rc ..\..\lib\liblualib.a *.o
%RANLIB% ..\..\lib\liblualib.a
del *.o

echo lua...
cd ..\lua
%CC% %CFLAGS% -o ..\..\bin\lua -I..\..\include *.c ..\..\lib\*.a -lm
%STRIP% ..\..\bin\lua.exe

echo luac...
cd ..\luac
%CC% %CFLAGS% -o ..\..\bin\luac -I..\..\include -I.. *.c -DLUA_OPNAMES ..\lopcodes.c ..\..\lib\*.a
%STRIP% ..\..\bin\luac.exe

echo done

cd ..\..\bin
lua.exe ..\test\hello.lua
cd ..
