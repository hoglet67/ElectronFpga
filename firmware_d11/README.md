This directory contains firmware for the ATSAMD11 chip on the
max10_electron_ula board.

It requires the MattairTech fork of ArduinoCore-samd to be installed;
see https://github.com/mattairtech/ArduinoCore-samd for instructions.

Bootloader programming
----------------------

The bootloader I'm using is sam_ba_Generic_D11C14A_SAMD11C14A.bin, from [this
archive](https://www.mattairtech.com/software/arduino/SAM-BA-bootloaders-zero-mattairtech.zip),
programmed using my J-Link like this:

~~~~
JLinkExe -device atsamd11c14 -if swd -speed 4000
connect
erase
loadbin sam_ba_Generic_D11C14A_SAMD11C14A.bin, 0
r
go
q
~~~~

After this, the board enumerates as a MattairTech LLC Generic SAMD11C14A, and I
can program it using the Arduino IDE, using the CDC_HID, 4KB_BOOTLOADER,
INTERNAL_USB_CALIBRATED_OSCILLATOR, and NO_UART_ONE_WIRE_ONE_SPI options.
