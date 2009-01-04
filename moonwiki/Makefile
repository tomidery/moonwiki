# MoonWiki

MINGW_HOME = C:/MinGW
CC   = $(MINGW_HOME)/bin/mingw32-gcc.exe 
LIBS =  -L$(MINGW_HOME)/lib -L../lua-5.0/lib -lwsock32 -llua -llualib 
INCS =  -I$(MINGW_HOME)/include  -I../lua-5.0/include
CFLAGS = -O2 $(INCS)


all: MoonWiki.exe

lua: 
	cd lua-5.0; make

clean-lua: 
	cd lua-5.0; make clean
	
MoonWiki.exe: MoonWiki.c
	$(CC) $(CFLAGS) -o MoonWiki MoonWiki.c $(LIBS)

