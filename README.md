# cpm-fat

CP/M for the Z80 Playground that runs on the FAT disk format. This enables you to run CP/M v2.2 on the Z80 Playground and transfer files easily to and from your PC, because this version of CP/M runs on FAT, so the files are compatible between Windows and CP/M.

For more details see https://8bitStack.co.uk

For videos about the Z80 Playground see https://youtube.com/playlist?list=PL3arA6T9kycptsudBx3MyLbHCOjdoBhO6

## Overview

The main parts of this repo are:

* CORE.ASM - The core routines for accessing the hardware.
* BIOS.ASM - A stub of a CP/M BIOS.
* BDOS.ASM - My implementation of the CP/M BDOS.
* CCP.ASM - The standard Digital Research CCP.

These should all be assembled into .BIN files and put into the /CPM directory or your USB Drive. The assembler I use is Pasmo.

Also, to get the system started, there is a boot loader called CPM.ASM. This should be assembled to CPM.HEX and put in the EEPROM.

## Releases

You can find the precompiled binary-files for previous releases beneath the [dist/](dist/) directory.   Place the contents of your chosen release into the `/CPM` directory on your USB drive then restart your system to take it into use.

## USB Drive

The full content of the USB Drive supplied with the kit can be found beneath the [disk/](disk/) directory.
