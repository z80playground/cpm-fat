# Overview

This repository contains the files required to get CP/M 2.2 running upon the "Z80 Playground" board - which uses a FAT filesystem hosted upon an external USB-stick.

For more details of the board, and discussion please see the official homepage:

* https://8bitStack.co.uk
  * [The forums](https://8bitstack.co.uk/forums/forum/z80-playground-early-adopters) contain more useful content too.
* You can also see various videos on youtube:
  * [Z80 Playground Playlist](https://www.youtube.com/playlist?list=PL3arA6T9kycptsudBx3MyLbHCOjdoBhO6)


## Contents

This repository contains two things:

* The assembly language source-files which will build CP/M.
* A set of binaries which can be copied to your USB-stick to produce a useful system.
  * Some of the binaries are generated from the sources beneath [Utils/](Utils/).

## Source Code

The source code available here is made of a couple of different files:

* CORE.ASM - The core routines for accessing the hardware.
* BIOS.ASM - A stub of a CP/M BIOS.
* BDOS.ASM - My implementation of the CP/M BDOS.
* CCP.ASM - The standard Digital Research CCP.

You can compile these via the `pasmo` compiler, or look at the latest versions upon our [releases page](https://github.com/skx/cpm-fat/releases).  If you have `make` and `pasmo` installed you can generate the compiled versions via:

     $ make

(The system will rebuild intelligently if you edit any included files.)

Regardless of whether you build from source, or download the prebuilt versions, you should place them upon your USB-stick beneath the top-level `/CPM` directory.

### Source Code Bootloader

To get the system started there is a boot loader compiled and stored within the EEPROM.  If you have a EEPROM programmer you should upload the contents of `CPM.BIN` to it.

The bootlaoder runs a simple monitor and allows CP/M to be launched.  Launching CP/M involves reading [/CPM/cpm.cfg](DISK/CPM/cpm.cfg) which contains the list objects to read into RAM, along with the addresses to which each should be loaded.  Once the files are loaded the system jumps to the CP/M entry-point.


## System Binaries

The full content of the USB Drive supplied with the kit can be found beneath the [DISK/](DISK/) directory.

CP/M doesn't have the concept of a directory, so all files are arranged at the top-level, however for organization different "drives" are used.

For example you'll find games installed beneath "G:", as you can see via:

    A> G:
    G> DIR
    ..
