
#
# The files we wish to generate.
#
all: chk16550.com locate.com monitor.com sd.com


#
# Cleanup
#
clean:
	rm *.com


#
# Convert an .asm file into a .com file, via pasmo.
#
%.com: %.asm
	pasmo $< $@
