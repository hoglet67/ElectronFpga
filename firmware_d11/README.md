This directory contains firmware for the ATSAMD11 chip on the
max10_electron_ula board.

It requires the MattairTech fork of ArduinoCore-samd to be installed;
see https://github.com/mattairtech/ArduinoCore-samd for instructions.

The Makefile needs arduino-cli to be installed, as well as the J-Link command
line tools.

Right now the code doesn't even fit in the 12kB left over once the bootloader
is added, so I have to build without the bootloader and program using the
J-Link.

~~~~
make clean upload; sleep 3; screen /dev/tty.usbmodem*; reset
~~~~
