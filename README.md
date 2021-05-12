
* [Overview](#overview)
* [Contents](#contents)
* [Source Code](#source-code)
  * [Bootloader](#bootloader)
* [CP/M Distribution Overview](#cpm-distribution-overview)
  * [CP/M System Changes](#cpm-system-changes)
    * [CLS](#cls)
    * [Search Path](#search-path)
    * [Input Handling](#input-handling)
    * [Removals](#removals)
    * [TODO?](#todo)
  * [CP/M Binaries](#cpm-binaries)
  * [Bootloader Changes](#bootloader-changes)
* [Useful Links](#useful-links)
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
* A set of binaries, organized into [distinct drives](#cpm-distribution-overview), which can be copied to your USB-stick to produce a useful system.
  * Some of the binaries are generated from the sources beneath [utils/](utils/), others are were obtained from historical release archives.


## Source Code

The source code available here is made of a couple of different files:

* [core.asm](core.asm) - The core routines for accessing the hardware.
* [bios.asm](bios.asm) - A stub of a CP/M BIOS.
* [bdos.asm](bdos.asm) - Implementation of the CP/M BDOS, as written by [John Squires](https://github.com/z80playground).
* [ccp.asm](ccp.asm) - The standard Digital Research CCP.

You can compile these via the `pasmo` compiler, or look at the latest versions upon our [releases page](https://github.com/skx/cpm-fat/releases).  If you have `make` and `pasmo` installed you can generate the compiled versions via:

     $ make

(The system will rebuild intelligently if you edit any included files.)

Regardless of whether you build from source, or download the prebuilt versions, you should place them upon your USB-stick beneath the top-level `/CPM` directory.

### Bootloader

To get the system started there is a boot loader compiled and stored within the EEPROM.  If you have a EEPROM programmer you should upload the contents of `CPM.HEX` to it, which is compiled from [cpm.asm](cpm.asm).

* I wrote some simple notes on [updating the bootloader](FLASH.md).

The bootloader runs a simple monitor and allows CP/M to be launched.  Launching CP/M involves reading [/CPM/cpm.cfg](dist/CPM/cpm.cfg) which contains the list objects to read into RAM, along with the addresses to which each should be loaded.  Once the files are loaded the system jumps into the monitor, from which you can launch CP/M, TinyBASIC, & etc.


## CP/M Distribution Overview

The full content of the USB stick supplied with the kit can be found beneath the [dist/](dist/) directory.

CP/M doesn't have the concept of sub-directories, so all files are arranged at the top-level, however for organization different "drives" are used.  To help keep things organize I've shuffled some of the contents around such that the binaries are grouped into a set of logical collections:


| Drive  | Contents                        | Notes                                          |
| ------ | ------------------------------- | ------------------------                       |
| A:     | All general-purpose utilities.  |                                                |
| B:     | BASIC Code and interpreter.     | Type `SYSTEM` to exit :)                       |
| C:     | AzTec C Compiler                | [Simple overview](C.md)                        |
| D:     |                                 |                                                |
| E:     | Editor - WordStar               |                                                |
| F:     | FORTH - DxForth                 |                                                |
| G:     | Games - all types               |                                                |
| H:     |                                 |                                                |
| I:     |                                 |                                                |
| J:     |                                 |                                                |
| K:     |                                 |                                                |
| L:     |                                 |                                                |
| M:     |                                 |                                                |
| N:     |                                 |                                                |
| O:     |                                 |                                                |
| P:     | Turbo Pascal 3.00A              | [Getting started with Turbo Pascal](TURBO.md). |

To look at the list of games, for example, you'll run something like this:

    A> G:
    G> DIR
    ..

Or:

    A> DIR G:*.COM


### CP/M System Changes

In terms of changing the system-core I have patched the CCP (command-processor) component of CP/M to change a couple of things:


#### CLS

There is a new built-in command `CLS` which will clear your screen.


#### Search Path

I've added a naive "search path", which allows commands to be executed from a different drive if not found in the present one.  By default nothing is configured:

     A>srch
     No search drive is configured

Now configure things to look for unknown commands on the A: drive, confirming that via executing a command that lives there:

     A>b:
     B>cls
     CLS?
     B>srch a
     Search drive set to A
     B>cls
     [ screen clears ]

#### Input Handling

I've updated the input-handler ("Read Console Buffer" / BIOS function 1) such that:

* The backspace key deletes the most recently entered character.
  * (This is in addition to the keystroke `C-h` continuing to work in that same way.)
* Ctrl-c cancels input.
  * (It returns an empty input-buffer, so it allows easy discarding.)

Now these two keystrokes work in a natural fashion at the CP/M prompt.


#### Removals

I've removed the undocumented (imp)ort and (exp)ort commands, to cut down on space, and avoid confusion.

This meant I could remove a little code from the CCP source, includeing:

* `debug:`
* `ADD32:` / `SUBTRACT32:`
* `display_hl32:` and `show_c_in_hex:`

If required those could be replaced by the existing code in [message.asm](message.asm) - just add an `include` and use them as-is.


#### TODO?

Possible future changes might involve:

* Optimize for size.
  * There are some simple changes which could be applied automatically.
  * For example replacing "`ld b,0`" with `xor b`.
* Look at `message.asm`
  * Which is a bit of a messy piece of code.


### CP/M Binaries

* I've added a copy of DX Forth beneath [F:](dist/CPM/DISKS/F).
* I've added a copy of the Turbo Pascal compiler beneath [P:](dist/CPM/DISKS/P).
  * I wrote a simple [getting started with Turbo Pascal](TURBO.md) guide.
  * Included is also a sample "hello.pas" file.
* I've added Zork 1, 2, & 3 beneath [G:](dist/CPM/DISKS/G).
  * I've designated the `G:` drive as the game-drive, and moved other games there too.
* I added `vi.com` to [A:](dist/CPM/DISKS/A).
  * This was obtained from [https://github.com/udo-munk/s/](https://github.com/udo-munk/s/).
  * While not a perfect version of `vi` it is pretty amazing considering.
* I added `ql.com` ("quick list")
  * After reading [this guide to text-pagers on CP/M](https://techtinkering.com/articles/text-viewers-on-cpm/).
* I added a couple of simple utilities to [A:](dist/CPM/DISKS/A), with source beneath [utils/](utils/):
  * `locate.com`
    * Find files matching a given pattern on **all** drives:
      * `LOCATE *.COM`.
    * or show all user-numbers which contain matches upon a single drive:
      * `LOCATE A:*.COM USER`.
      * Note that user-numbers seem to be slightly broken in this distribution.
  * `monitor.asm`
    * Jump back to the monitor, from within the CP/M environment.
    * Essentially page in the ROM, then reboot.
* I removed duplicate file-contents from various drives.


### Bootloader Changes

* I've patched TinyBASIC such that the `EXIT` keyword will restart the system.
  * Otherwise there was no way back to the BIOS/menu short of hitting the reset-switch.


# Useful Links

* CP/M help and information:
  * [CP/M Commands](http://www.primrosebank.net/computers/cpm/cpm_commands.htm)
* CP/M Software
  * [Commercial CP/M Software Archive](http://www.retroarchive.org/cpm/index.html)
  * [The HUMONGOUS CP/M Software Archives](http://cpmarchives.classiccmp.org/)
* [WordStar Keyboard Bindings](http://www.wordstar.org/index.php/wsdos-documentation/wsdos-commands/108-wordstar-3-for-dos-commands-reference)

This repository contains a copy of Turbo Pascal, along with a [guide to using it](TURBO.md), you can find a couple of simple games online here:

* [Snake](https://github.com/linker3000/Z80-Board/blob/master/snake.pas)
* [Quatris](https://web.archive.org/web/20080209232438/http://www.cirsovius.de/CPM/Projekte/Decompiler/QUATRIS/QUATRIS-PAS.txt) ("tetris")


# Future plans?

* Optimize some of the assembly for size.
  * Obvious easy-win is replacing instructions such as `ld b,0` with `xor b`.
* Make a couple of minor changes to ccp:
  * Would be nice to have command-history, accessible via `M-n`/`M-p`, or the arrow-keys.
  * I added `cls.com`, it might make more sense to build that into the CCP-shell.
