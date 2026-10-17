#
# SPDX-License-Identifier: MIT
#
# This is a makefile for Borland MAKE as it comes with Borland Pascal.
#
# BROOT must be configured to point to your Borland Pascal installation.
#

BPROOT	 = c:\bp
RTL	 = $(BPROOT)\units

BPCFLAGS = /U$(RTL)
BPC      = $(BPROOT)\bin\bpc.exe $(BPCFLAGS) $(FLAGS)

AFLAGS   = -t -w1 -m4 -z -zd -p
TASM     = $(BPROOT)\bin\tasm.exe $(AFLAGS)

MKDIR	 = md
CP       = copy
RM       = del
RMDIR    = rd

all:	 ucsockd.exe ucsockp.exe

.asm.obj:
	$(TASM) $<,build\$@;

ucsockd.exe: prepare csock.obj
	$(BPC) -CD ucsock.pas
	$(CP) build\ucsock.exe build\ucsockd.exe
	$(RM) build\ucsock.exe

ucsockp.exe: prepare csock.obj
	$(BPC) -CP ucsock.pas
	$(CP) build\ucsock.exe build\ucsockp.exe
	$(RM) build\ucsock.exe

prepare:
	-$(MKDIR) build

clean:
	-$(RM) build\*.obj
	-$(RM) build\*.tpu
	-$(RM) build\*.tpp
	-$(RM) build\*.exe
	-$(RM) build\*.map
	-$(RMDIR) build
