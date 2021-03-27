# Updating Z80 Playground Firmware

The system boots via the code on the EEPROM-chip, if you wish to change the monitor, or the bootup process you'll want to update that, which is a two-part process:

* Making the appropriate change in source, and rebuilding the firmware.
* Uploading the firmware to the EEPROM, so it will actually be used.


## Rebuilding Firmware

Rebuilding the firmware should be a simple matter of running `make` within this repository:

    $ rm *.hex
    $ make
    pasmo cpm.asm  cpm.hex
    $ ls -l *.hex
    -rw-r--r-- 1 skx skx 18779 Mar 27 19:12 cpm.hex
    $

As you can see the firmware is created from the source [cpm.asm](cpm.asm), and this in turn includes other files as appropriate.


## Firmware Uploading

To update the flash on the EEPROM you'll need a hardware programmer, I'm using a generic "TL866II Plus Universal Minipro Programmer", which I chose from AliExpress based solely the seller which claimed fastest shipping.

As I'm on a GNU/Linux host, running Debian, I installed the software from this repository:

* https://gitlab.com/DavidGriffith/minipro/

The EEPROM is labeled "28C256 - 32K EEPROM" in the system schematic so this, which helps narrow things down nicely.


### Backup EEPROM

To backup the existing contents of the EEPROM:

     $ minipro -p "AT28C256" -r eeprom.bin


### Update EEPROM

Send the contents of `cpm.hex` to the device:

     $ minipro -p "AT28C256" -w cpm.hex

Once written you can, and should, verify the contents, for safety:

     $ minipro -p "AT28C256" -m cpm.hex
