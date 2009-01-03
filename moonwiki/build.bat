@echo off

REM configuration for MinGW:
SET MINGW_HOME=C:\MinGW
SET CC=%MINGW_HOME%\bin\mingw32-gcc.exe
SET STRIP=%MINGW_HOME%\bin\strip.exe
SET INCS=-I%MINGW_HOME%\include -Ilua-5.0\include
SET LIBS=-L%MINGW_HOME%\lib -Llua-5.0\lib -lwsock32 -llua -llualib 

echo building MoonWiki...

%CC% -O2 %INCS% MoonWiki.c -o MoonWiki %LIBS% 
del MoonWiki.o
%STRIP% MoonWiki.exe

echo done
