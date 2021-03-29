# XMODEM

You can transfer files to the running system via the xmodem tools:

* XR - Xmodem Receive for Z80 CP/M 2.2 using CON:
* XS - Xmodem Send for Z80 CP/M 2.2 using CON:

The source code for these two tools can be found here:

* https://github.com/SmallRoomLabs/xmodem80/
  * **NOTE** The bugfix in [#2](https://github.com/SmallRoomLabs/xmodem80/issues/2) has been applied to the binaries included here.

On your system you'll want to install the [lrzsz package](https://packages.debian.org/lrzsz)



# Sending A File

Connect GNU Screen to your running system:

    screen /dev/ttyUSB0 115200

Then run:

    a>xr foo
    CP/M XR - Xmodem receive v0.1 / SmallRoomLabs 2017

Enter `Ctrl-a :` into your GNU Screen window, which will open the command-prompt, and then type:

    exec !! sx /etc/passwd

As a result of this `/etc/passwd` from your system will be stored as `foo` within the system.


# Retrieving A File

To retrieve a file from the running Z80 Playground you run a similar process, connect GNU Screen and run the sending command:

    A> xs B:LINK.COM

Now enter the GNU Screen prompt by prcessing `Ctrl-a :`, and enter the following to trigger the receiver:

    exec !! rx /tmp/received

Now `B:LINK.COM` will exist as `/tmp/received` upon your host.
