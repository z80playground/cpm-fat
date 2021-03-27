
* [Overview](#overview)
* [Contents](#contents)
* [Source Code](#source-code)
  * [Bootloader](#bootloader)
* [CP/M Binaries](#cpm-binaries)
  * [Additions](#additions)
* [Future Plans?](#future-plans)

# Overview

This repository contains a distribution of CP/M 2.2, which can run upon the "Z80 Playground" board.  The Z80 Playground single-board computer uses an external FAT-filesystem stored upon a USB-Stick to provide storage, giving it very easy interoperability with an external computer.

For more details of the board please see the official homepage:

* https://8bitStack.co.uk
  * [The forums](https://8bitstack.co.uk/forums/forum/z80-playground-early-adopters) contain more useful content too.
* You can also see various videos on youtube:
  * [Z80 Playground Playlist](https://www.youtube.com/playlist?list=PL3arA6T9kycptsudBx3MyLbHCOjdoBhO6)


## Contents

This repository contains two things:

* The assembly language source-files which will build CP/M.
* A set of binaries, organized into [distinct drives](#cpm-binaries), which can be copied to your USB-stick to produce a useful system.
  * Some of the binaries are generated from the sources beneath [utils/](utils/), others are were obtained from historical release archives.


## Source Code

The source code available here is made of a couple of different files:

* [core.asm](core.asm) - The core routines for accessing the hardware.
* [bios.asm](bios.asm) - A stub of a CP/M BIOS.
* [bdos.asm](bdos.asm) - My implementation of the CP/M BDOS.
* [ccp.asm](ccp.asm) - The standard Digital Research CCP.

You can compile these via the `pasmo` compiler, or look at the latest versions upon our [releases page](https://github.com/skx/cpm-fat/releases).  If you have `make` and `pasmo` installed you can generate the compiled versions via:

     $ make

(The system will rebuild intelligently if you edit any included files.)

Regardless of whether you build from source, or download the prebuilt versions, you should place them upon your USB-stick beneath the top-level `/CPM` directory.

### Bootloader

To get the system started there is a boot loader compiled and stored within the EEPROM.  If you have a EEPROM programmer you should upload the contents of `CPM.HEX` to it, which is compiled from [cpm.asm](cpm.asm).

* I wrote some simple notes on [updating the bootloader](FLASH.md).

The bootloader runs a simple monitor and allows CP/M to be launched.  Launching CP/M involves reading [/CPM/cpm.cfg](dist/CPM/cpm.cfg) which contains the list objects to read into RAM, along with the addresses to which each should be loaded.  Once the files are loaded the system jumps into the monitor, from which you can launch CP/M, TinyBASIC, & etc.


## CP/M Binaries

The full content of the USB stick supplied with the kit can be found beneath the [dist/](dist/) directory.

CP/M doesn't have the concept of sub-directories, so all files are arranged at the top-level, however for organization different "drives" are used.  To help keep things organize I've shuffled some of the contents around such that the binaries are grouped into a set of logical collections:


| Drive  | Contents                        |
| ------ | ------------------------------- |
| A:     | All general-purpose utilities.  |
| B:     | BASIC Code and interpreter.     |
| C:     | AzTec C Compiler/Linker               |
| D:     | Wordstar files?  [TODO: Move]   |
| E:     | Editor - WordStar               |
| F:     | Z80 FORTH [TODO]                |
| G:     | Games - all types               |
| H:     |                                 |
| I:     |                                 |
| J:     |                                 |
| K:     |                                 |
| L:     |                                 |
| M:     |                                 |
| N:     |                                 |
| O:     |                                 |
| P:     | Tturbo Pascal 3.00A             |

To look at the list of games, for example, you'll run something like this:

    A> G:
    G> DIR
    ..

Or:

    A> DIR G:*.COM



### Additions

* Currently the source of the runtime system hasn't been changed, instead I've shuffled the various executables around for clarity.
* I've added a copy of the Turbo Pascal compiler beneath [P:](dist/CPM/DISKS/P).
  * I wrote a simple [getting started with Turbo Pascal](TURBO.md) guide.
  * Included is also a sample "hello.pas" file.
* I've added Zork 1, 2, & 3 beneath [G:](dist/CPM/DISKS/G).
  * I've designated the `G:` drive as the game-drive, and moved other games there too.
* I added a couple of simple utilities to [A:](dist/CPM/DISKS/A), with source beneath [utils/](utils/):
  * `locate.com`
    * Find files matching a given pattern on **all** drives:
      * `LOCATE *.COM`.
    * or show all user-numbers which contain matches upon a single drive:
      * `LOCATE A:*.COM USER`.
  * `cls.com` - Clear the screen, by outputting an appropriate ANSI escape sequence.


# Future plans?

* Optimize some of the assembly for size.
  * Obvious easy-win is replacing instructions such as `ld b,0` with `xor b`.
* Make a couple of minor changes to ccp:
  * Would be nice to have command-history, accessible via `M-n`/`M-p`, or the arrow-keys.
  * I added `cls.com`, it might make more sense to build that into the CCP-shell.
