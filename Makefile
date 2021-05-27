
#
# The files we wish to generate.
#
all: bdos.bin bios.bin ccp.bin core.bin z80ccp.bin cpm.hex


#
# Cleanup.
#
clean:
	rm *.bin *.hex

#
# This is a magic directive which allows GNU Make to perform
# a second expansion of things before running.
#
# In this case we wish to dynamically get the dependencies
# of the given .asm file.  We do that by loading a perl-script
# to look for `include "xxx"` references in the input file,
# and processing them recursively.
#
.SECONDEXPANSION:

#
# Convert an .asm file into a .bin file, via pasmo.
#
# The $$(shell ...) part handles file inclusions, so if you
# were to modify "locatoins.asm", for example, all appropriate
# binary files would be rebuilt.
#
%.bin: %.asm $$(shell ./gendep %.asm)
	pasmo $<  $@

%.hex: %.asm $$(shell ./gendep %.asm)
	pasmo $<  $@


sync:
	cp *.bin dist/CPM/
	cp *.hex dist/CPM/
	rsync  -vazr dist/CPM/ /media/skx/8BITSTACK/CPM/
